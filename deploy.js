//import TronWeb from 'tronweb'
TronWeb = require('tronweb');
fs = require('fs')

File = (name) => fs.readFileSync(name)
FileWrite = (file, data) => fs.writeFileSync(file, data)
Json = JSON.parse;
JsonDump = JSON.stringify;


//const shasta = '.shasta'
const shasta = ''

const fullNode = `https://api${shasta}.trongrid.io`;
const solidityNode = `https://api${shasta}.trongrid.io`;
const eventServer = `https://api${shasta}.trongrid.io/`;
const anyPrivate = File(".key").toString();
const bet16Address = 'TWE37uQa9gDkWnHN5SdZC9XsWCX2m8dwro';

const tronWeb = new TronWeb(
    fullNode,
    solidityNode,
    eventServer,
    anyPrivate
);

const D = console.info;


//D(tronWeb.address.toHex())
//tronWeb.address.fromHex
function helpAPI() {
    enadd = tronWeb.address.fromPrivateKey(anyPrivate)
    hexadd = tronWeb.address.toHex(enadd)
    tadd = tronWeb.address.fromHex(hexadd)
    D(enadd, hexadd, tadd == enadd)
}

function getContract(addr){
    return tronWeb.contract().at(addr).then(
        (x) => {return x;}
    );
}

function localContract(abi, addr) {
    return tronWeb.contract(Json(abi), addr)
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

function deploy_contract(cinfo, input){
  return tronWeb.contract().new({
    abi:cinfo.abi,
    bytecode:cinfo.bin,
    feeLimit: 1000000000,
    callValue: 0,
    userFeePercentage: 1,
    parameters:input
  });
}

function sendTx(txobj, trx=0, fee=2, sync=true) {
    return txobj.send({
        feeLimit: tronWeb.toSun(fee),
        shouldPollResponse: sync,
        callValue: tronWeb.toSun(trx),
    });
}

function parseCombinedJson(filename) {
    combindedObj = Json(File(filename));
    D("compiler:", combindedObj.version);
    return combindedObj.contracts;
}

async function coinpool_Deploy_main(){
    helpAPI();
    contractMap = parseCombinedJson(process.argv[2])
    mainEntry = contractMap['CoinPool.sol:CoinPool']
    mainEntryDeploy = await deploy_contract(mainEntry, ["TC6ixKGqM9Xp6T1emfXjmCB8Zf1THRro4G", 1003035, 1003036, 1003037])
    D("mainEntry:", mainEntryDeploy.address, tronWeb.address.fromHex(mainEntryDeploy.address))
    let owner = await mainEntryDeploy.owner().call();
    D("owner:", owner);
    D("lbt:", await mainEntryDeploy.tokenIdLBT().call());
    D("rlbt:", await mainEntryDeploy.tokenIdRLBT().call());
    D("tg:", await mainEntryDeploy.tokenIdTG().call());
}

async function coinpool_check_main(){
    let coinpool = await getContract("TYx78gQtzu6B44qBD3Y2tC2kC42A7fNJ74");
    let owner = await coinpool.owner().call();
    D("owner:", owner);
    D("tokenIdRTRX", await coinpool.tokenIdRTRX().call())
}

async function game_Deploy_main(){
    helpAPI();
    contractMap = parseCombinedJson(process.argv[2])
    mainEntry = contractMap['GameImpl.sol:HappyScratch']
    mainEntryDeploy = await deploy_contract(mainEntry, ["HappyScratch_TG","TZBFjhFY1aDHaYN7Tt6EUmqXdAyao9WYes"])
    D("mainEntry:", mainEntryDeploy.address, tronWeb.address.fromHex(mainEntryDeploy.address))
    let owner = await mainEntryDeploy.owner().call();
    D("owner:", owner,tronWeb.address.fromHex(owner));
    D("tokenIdLBT", (await mainEntryDeploy.tokenIdLBT().call()).toString());
    D("tokenIdRLBT", (await mainEntryDeploy.tokenIdRLBT().call()).toString());
    D("tokenIdTG", (await mainEntryDeploy.tokenIdTG().call()).toString());
}

async function game_check_main(){
    contractMap = parseCombinedJson(process.argv[2])
    let HappyScratch = localContract(contractMap['GameImpl.sol:HappyScratch'].abi, "TAs2dESvB9PwsNZpjcLYqG4xAWve54nRbR");
    D("name", await HappyScratch.name().call());
    D("_CoinPool", tronWeb.address.fromHex(await HappyScratch._CoinPool().call()))
    D("owner", await HappyScratch.owner().call());
    D("opening", await HappyScratch.opening().call());
    let happyhash = localContract(contractMap['GameImpl.sol:HappyHash'].abi, "TQ3nrH2Z3vrGLnEfDyAtvt6hshJMyNAxtQ");
    D("name", await HappyScratch.name().call());
    D("_CoinPool", tronWeb.address.fromHex(await HappyScratch._CoinPool().call()))
    D("owner", await happyhash.owner().call());
    D("opening", await happyhash.opening().call());
    let happyhash16 = localContract(contractMap['GameImpl.sol:HappyHash16'].abi, "TAUAg7AQmrbq3wGJ6rA7x9xdcrK82GuFzk");
    D("name", await HappyScratch.name().call());
    D("_CoinPool", tronWeb.address.fromHex(await HappyScratch._CoinPool().call()))
    D("owner", await happyhash16.owner().call());
    D("opening", await happyhash16.opening().call());
}

function main(){
    game_check_main();
}

main();
