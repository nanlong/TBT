pragma solidity >=0.4.0;

contract CoinPool{
    uint256 public tokenIdRTRX;
    address public  owner;
    function isOpen() external view returns(bool);
    function transfer(address to, uint256 _amount) external;
    function transferTBT(address to,uint256 _amount)external;
    function ()payable external;
}

contract Game{
    function isWin(uint256 betType, uint256 betHash) internal pure returns (bool, uint256);

    string public name;
    address public owner;
    CoinPool public  _CoinPool;
    uint256 public tokenIdRTRX;
    struct BetStruct {
        uint256 betInfoEn; //
    }
    event betLog(address player, uint256 betType, uint256 betValue, uint256 tokenValue);
    event openLog(address player, uint256 betType, uint256 betValue, uint256 tokenValue, bool win);
    uint256 public nextOpen;
    bool public opening;
    BetStruct[16] public BetRecord;
    BetStruct[] public BetRecordExtend;

    modifier onlyOwner(){require(msg.sender==owner);_;}
    modifier gameOpened(){require(opening);_;}
    constructor(string _name, address pool)public{
        name = _name;
        _CoinPool = CoinPool(pool);
        update();
        nextOpen = 0;
    }
    function update() public {
        owner = _CoinPool.owner();
        tokenIdRTRX = _CoinPool.tokenIdRTRX();
        opening = _CoinPool.isOpen();
    }
    function switchCoinPool(address pool) external onlyOwner{
        _CoinPool = CoinPool(pool);
        update();
    }
    function getFreeSlot() internal returns(BetStruct storage ibet){
        if (true || BetRecord[BetRecord.length-1].betInfoEn > 0){
            BetRecordExtend.length++;
            return BetRecordExtend[BetRecordExtend.length-1];
        }
        for(uint256 i = 0; i < BetRecord.length; i++){
            ibet = BetRecord[i];
            if (ibet.betInfoEn == 0)
                break;
        }
        return ibet;
    }
    function encode(address player, uint256 trxvalue, uint256 rtrxvalue, uint256 number,uint256 betType)internal pure returns(uint256){
        require(trxvalue < ((1<<31)*1e6) && 
                rtrxvalue < ((1<<31)*1e6) && 
                number < (1<<32) &&
                betType < (1<<32) &&
                uint256(player) < (1<<160));
        uint256 value = trxvalue/1e6;
        if (rtrxvalue > 0) {
            value = rtrxvalue/1e6;
            value |= 1<<31;
        }
        return uint256(player)<<(12*8) | value<<(8*8) | number<<(4*8) | betType;
    }
    function decode(uint256 en) internal pure returns(address player, uint256 trxvalue, uint256 rtrxvalue, uint256 number,uint256 betType){
        player = address(en >> (12*8));
        trxvalue = rtrxvalue = 0;
        uint256 value = (en >> (8*8));
        if ((value & (1<<31)) > 0)
            rtrxvalue = (value & ((1<<31) - 1))*1e6;
        else
            trxvalue = (value & ((1<<31) - 1))*1e6;
        number = (en >> (4*8)) & ((1<<32) - 1);
        betType = en & ((1<<32) - 1);
    }
    function bet(uint256 betType) external payable gameOpened{
        if (msg.tokenid == tokenIdRTRX){
            require(msg.tokenvalue >= 20e6 && msg.tokenvalue < address(_CoinPool).balance/10);
            _CoinPool.transferTBT(msg.sender, msg.tokenvalue*1e9); // big gas 352110 sun
        }else{
            require(msg.value >= 20e6 && msg.value < address(_CoinPool).balance/10);
            _CoinPool.transferTBT(msg.sender, msg.value*1e9); // big gas
        }
        BetStruct storage ibet = getFreeSlot();
        ibet.betInfoEn = encode(msg.sender, msg.value, msg.tokenvalue, block.number, betType); // encode: small gas 3820 sun
        emit betLog(msg.sender, betType, msg.value, msg.tokenvalue); // gas 19170 sun
    }

    function openall() external{
        openFixedRecord();
        if(BetRecord.length > 0)
            openExtendRecord(BetRecord.length);
    }

    function dealTRX(address player, uint256 trxvalue, bool win, uint256 n) internal {
        if (!win){ // loose, transfer TRX to coinpool
            address(_CoinPool).transfer(trxvalue);
            return;
        }
        uint256 total = trxvalue*970/100/n;
        if (total > trxvalue){
            player.transfer(trxvalue);
            _CoinPool.transfer(player, total - trxvalue);
        }else{
            player.transfer(total);
            address(_CoinPool).transfer(trxvalue-total);
        }
    }

    function dealRTRX(address player, uint256 rtrxvalue, bool win, uint256 n) internal {
        if (!win){ // loose, transfer RTRX to coinpool
            address(_CoinPool).transferToken(rtrxvalue, tokenIdRTRX);
            return;
        }
        uint256 total = rtrxvalue*970/100/n;
        if (total > rtrxvalue){
            player.transferToken(rtrxvalue, tokenIdRTRX);
            _CoinPool.transfer(player, total - rtrxvalue);
        }else{
            player.transferToken(rtrxvalue, total);
            address(_CoinPool).transferToken(total-rtrxvalue, tokenIdRTRX);
        }
    }

    function openFixedRecord() public {
        uint256 betHash;
        uint256 betNumber = 0;
        for(uint256 i = 0; i < BetRecord.length; i++){
            BetStruct storage ibet = BetRecord[i];
            if (ibet.betInfoEn == 0){
                break;
            }
            (address player, uint256 trxvalue, uint256 rtrxvalue, uint256 number, uint256 betType) = decode(ibet.betInfoEn);
            if (number >= block.number)
                break;
            if (betNumber != number)
                betHash = uint256(blockhash(number));
            (bool win, uint256 n) = isWin(betType, betHash);
            if(trxvalue > 0)
                dealTRX(player, trxvalue, win, n);
            else
                dealRTRX(player, rtrxvalue, win, n);
            emit openLog(player, betType, trxvalue, rtrxvalue, win);
            delete BetRecord[i];
        }
    }

    function openExtendRecord(uint256 num) public{
        if (BetRecordExtend.length == 0)
            return;
        uint256 end = num+nextOpen;
        if (end > BetRecordExtend.length)
            end = BetRecordExtend.length;
        uint256 i = 0;
        uint256 betHash;
        uint256 betNumber = 0;
        for(i = nextOpen; i < end; i++){
            BetStruct storage ibet = BetRecordExtend[i];
            (address player, uint256 trxvalue, uint256 rtrxvalue, uint256 number, uint256 betType) = decode(ibet.betInfoEn);
            if (number >= block.number)
                break;
            if (betNumber != number)
                betHash = uint256(blockhash(number));
            (bool win, uint256 n) = isWin(betType, betHash);
            if(trxvalue > 0)
                dealTRX(player, trxvalue, win, n);
            else
                dealRTRX(player, rtrxvalue, win, n);
            emit openLog(player, betType, trxvalue, rtrxvalue, win);
        }
        if (i == BetRecordExtend.length){
            nextOpen = 0;
            delete BetRecordExtend;
        }else{
            nextOpen = i;
        }
    }

    function xopen(uint256 num) public view returns(address, uint256, bool, uint256){
        BetStruct memory ibet;
        if (num < BetRecord.length){
            ibet = BetRecord[num];
        }else {
            ibet = BetRecordExtend[num - BetRecord.length];
        }
        (address player, uint256 trxvalue, uint256 rtrxvalue, uint256 number, uint256 betType) = decode(ibet.betInfoEn);
        uint256 betHash = uint256(blockhash(number));
        (bool win, uint256 n) = isWin(betType, betHash);
        if(win){
            if(trxvalue > 0){
                return (player, trxvalue*970/100/n, win, n);
            }else{
                return (player, rtrxvalue*970/100/n, win, n);
            }
        }else{
            if(trxvalue > 0){
                return (player, rtrxvalue, win, n);
            }else{
                return (player, rtrxvalue, win, n);
            }
        }
    }

    function withdraw() external onlyOwner {
        if (BetRecord.length == 0){
            msg.sender.transfer(address(this).balance);
        }
    }

    function withdrawToken(uint256 tokenID) external onlyOwner {
        if (BetRecord.length == 0){
            msg.sender.transferToken(address(this).tokenBalance(tokenID), tokenID);
        }
    }


    function gbetNum() external view returns(uint256){
        uint256 n = 0;
        for(uint256 i = 0; i < BetRecord.length; i++){
            if (BetRecord[i].betInfoEn == 0)
                break;
            n++;
        }
        return n+BetRecordExtend.length;
    }

    function gblockhash(uint256 number) public view returns (bytes32, bytes1, uint256){
        bytes32 h = blockhash(number);
        return (h, h[31], uint256(h)&0xff);
    }

    function curblock() public view returns (bytes32, bytes1, uint256){
        return gblockhash(block.number-1);
    }

    function ()payable external{}
}