# -*- coding: UTF-8 -*-
from http import client
import json
from urllib import parse
import gzip
from io import BytesIO
import datetime
import sys

def jsonDump(obj):
    return json.dumps(obj, separators=(',',':'))

def jsonLoad(jstr):
    if type(jstr) == bytes:
        jstr = jstr.decode('utf8')
    return json.loads(jstr)

def gzdecode(data) :
    compressedstream = BytesIO(data)
    gziper = gzip.GzipFile(fileobj=compressedstream)  
    data2 = gziper.read()
    return data2

def HttpsReq(host, method, url, body=None, header={}):
    while True:
        try:
            conn=client.HTTPSConnection(host)
            conn.request(method, url, body, header)
            res=conn.getresponse()
            if res.status == 301:
                return {"status":"wait"}
            if res.status:
                compress = res.getheader('content-encoding')
                cookie = res.getheader('Cookie')
                if cookie != None:
                    header['Cookie']=cookie
                if compress == "gzip":
                    de = gzdecode(res.read())
                    return jsonLoad(de)
                else:
                    return jsonLoad(res.read())
        except:
            print('try again')
            pass
contract = '41f9bfd855f024d7ac0323e160683b41d92af3a8dc'
betLog = '4962d09e963910184cdf2ec784a3ba99b89967affcf78e47269e7b279ad30543'
address = sys.argv[1]

txids = []

def matchTxs(txids, resp):
    txs = resp['data']
    for tx in txs:
        if tx.get('raw_data') is None:
            continue
        call = tx['raw_data'].get('contract')
        if call is None:
            continue
        if len(call) > 1:
            print('--------',call)
            exit(0)
        if call[0]['type'] != 'TriggerSmartContract':
            continue
        to =  call[0]['parameter']['value']['contract_address']
        if to != contract:
            continue
        txids.append({'txid':tx['txID']})
def GetTxsByAccount(address, txids):
    rawurl='https://api.trongrid.io:443/v1/accounts/%s/transactions?only_confirmed=true&only_from=true&limit=200'%address
    while True:
        print(rawurl)
        urls = parse.urlparse(rawurl)
        host= urls.netloc
        path=urls.path+'?'+urls.query
        try:
            resp = HttpsReq(host, 'GET', path)
        except:
            print("excpet!")
            continue
        matchTxs(txids, resp)
        links = resp['meta'].get('links')
        if links is None:
            return
        rawurl = links['next']

GetTxsByAccount(address, txids)

def getTxByID(txid):
    host='api.trongrid.io'
    url='/wallet/gettransactioninfobyid'
    postdata = '{"value":"%s"}'%txid['txid']
    resp = HttpsReq(host, 'POST', url, postdata)
    txid['time'] = resp['blockTimeStamp']/1000
    txid['height'] = resp['blockNumber']
    receipt = resp['receipt']
    txid['status'] = receipt['result']
    if txid['status'] == 'REVERT':
        return
    logs = resp.get('log')
    if logs is None:
        print(resp)
    for log in logs:
        if log['address'] == contract[2:] and log['topics'][0] == betLog:
            txid['id'] = log['data']
            txid['parseid'] = parseID(txid['id'])

def getHashByNum(num):
    host='api.trongrid.io'
    url='/wallet/getblockbynum'
    postdata = '{"num":%d}'%num
    resp = HttpsReq(host, 'POST', url, postdata)
    return resp['blockID']
def hashToNumber(_hash):
    number = int(_hash, 16)
    while ((number & 0xf) >= 10):
        number >>= 4
    return number&0xf
def isWin(betType, openNumber, betValue):
    betType = betType&(0x3ff)
    winFlag = 1<<(openNumber&0xf)
    if (betType & winFlag)==0:
        return 0
    n = 0
    while betType > 0:
        n=n+1
        betType &= betType - 1
    return betValue*970.0/100/n if  n > 0 else 0

def parseID(bid):
    max32 = 0xffffffff
    max31 = max32>>1
    o={}
    n256 = int(bid, 16)
    o['player'] = hex(n256>>96)
    value = (n256 >> (8*8))&max32
    o['isTrx'] = (value & (1<<31)) == 0
    o['value'] = value & max31
    o['number'] = (n256>>(4*8)) & max32
    o['bettype'] = []
    bettype = n256 & max32
    for i in range(10):
        if bettype&(1<<i):
            o['bettype'].append(i)
    o['rawtype'] = bettype
    return o

def timeStr(stamp):
    dateArray = datetime.datetime.fromtimestamp(stamp)
    return dateArray.strftime('%Y/%m/%d %H:%M:%S')

def printLog(txid, txn, total, f=None):
    print('-'*80, txn, total, file=f)
    print('交易哈希:\t%s'%txid['txid'], file=f)
    print('交易状态:\t%s'%('下注失败' if txid['status'] == 'REVERT' else '下注成功'), file=f)
    print('打包时间:\t%s'%timeStr(txid['time']), file=f)
    print('区块高度:\t%d'%txid['height'], file=f)
    print('区块哈希:\t%s'%txid['hash'], file=f)
    if txid['status'] == 'REVERT':
        return
    print('开奖数字:\t%d'%txid['opennumber'], file=f)
    print('下注数字:\t%s'%txid['parseid']['bettype'], file=f)
    print('下注总额:\t%.2f %s'%(txid['parseid']['value'], 'TRX' if txid['parseid']['isTrx'] else 'RTRX'), file=f)
    if txid['parseid']['isTrx']:
        print('返奖结果:\t%.2f TRX\t0 RTRX'%txid['win'], file=f)
    elif txid['win'] > txid['parseid']['value']:
        print('返奖结果:\t%.2f TRX\t%.2f RTRX'%(txid['win']-txid['parseid']['value'], txid['parseid']['value']), file=f)
    else:
        print('返奖结果:\t0 TRX\t%.2f RTRX'%txid['win'], file=f)

f = open('%s.txt'%address, 'w')
txn = 0
for txid in txids:
    getTxByID(txid)
    txid['hash'] = getHashByNum(txid['height'])
    txid['opennumber'] = hashToNumber(txid['hash'])
    if txid['status'] != 'REVERT':
        txid['win'] = isWin(txid['parseid']['rawtype'], txid['opennumber'], txid['parseid']['value'])
    printLog(txid, txn, len(txids), f)  
    printLog(txid, txn, len(txids))
    txn+=1 

