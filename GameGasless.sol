pragma solidity >=0.4.0;

contract CoinPool{
    uint256 public tokenIdRTRX;
    address public  owner;
    function isOpen() external view returns(bool);
    function transfer(address to, uint256 _amount) external;
    function transferTBTAndTBS(address to,uint256 _TBT, uint256 _TBS) external;
    function ()payable external;
}

contract Game{
    // 判断输赢 返回赢取的总数
    function isWin(uint32 betType, uint256 openNumber, uint256 betValue) internal pure returns (uint256 totalValue);
    // hash 到 number的转换函数
    function hashNumber(bytes32 betHash) internal pure returns(uint256 number);

    string public name;
    address public owner;
    CoinPool public  _CoinPool;
    uint256 public tokenIdRTRX;
    struct BetStruct {
        uint256 betInfoEn; //
    }
    event betLog(bytes32 id);
    //event openLog(uint256 id, uint256 totalValue);
    uint256 public nextOpen;
    bool public opening;
    BetStruct[16] public BetRecord;
    BetStruct[] public BetRecordExtend;
    mapping(uint256=>bytes32) public Hashes;

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

    function FeedHashes(uint256 number, uint256 _hash) external onlyOwner{
        Hashes[number] = bytes32(_hash);
    }

    function getHashByNumber(uint256 number)internal view returns (bytes32 _hash){
        _hash = blockhash(number);
        if(uint256(_hash) > 0)
            return;
        _hash = Hashes[number];
        require(uint256(_hash) > 0);
    }

    function getFreeSlot() internal returns(BetStruct storage ibet){
        if (BetRecord[BetRecord.length-1].betInfoEn > 0){
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
    function encode(address player, uint256 trxvalue, uint256 rtrxvalue, uint256 number,uint32 betType)internal pure returns(uint256){
        require(trxvalue < ((1<<31)*1e6) && 
                rtrxvalue < ((1<<31)*1e6) && 
                number < (1<<32) &&
                uint256(player) < (1<<160));
        uint256 value = trxvalue/1e6;
        if (rtrxvalue > 0) {
            value = rtrxvalue/1e6;
            value |= 1<<31;
        }
        return uint256(player)<<(12*8) | value<<(8*8) | number<<(4*8) | betType;
    }
    function decode(uint256 en) internal pure returns(address player, uint256 trxvalue, uint256 rtrxvalue, uint256 number,uint32 betType){
        player = address(en >> (12*8));
        trxvalue = rtrxvalue = 0;
        uint256 value = (en >> (8*8));
        if ((value & (1<<31)) > 0)
            rtrxvalue = (value & ((1<<31) - 1))*1e6;
        else
            trxvalue = (value & ((1<<31) - 1))*1e6;
        number = (en >> (4*8)) & ((1<<32) - 1);
        betType = uint32(en);
    }
    function tibet(uint32 betType) internal gameOpened{
        if (msg.tokenid == tokenIdRTRX){
            require(msg.tokenvalue >= 20e6 && msg.tokenvalue < address(_CoinPool).balance/10);
            _CoinPool.transferTBTAndTBS(msg.sender, msg.tokenvalue*1e9, msg.tokenvalue); // big gas 352110 sun
        }else{
            require(msg.value >= 20e6 && msg.value < address(_CoinPool).balance/10);
            _CoinPool.transferTBTAndTBS(msg.sender, msg.value*1e9, msg.value); // big gas
        }
        BetStruct storage ibet = getFreeSlot();
        ibet.betInfoEn = encode(msg.sender, msg.value, msg.tokenvalue, block.number, betType); // encode: small gas 3820 sun
        emit betLog(bytes32(ibet.betInfoEn)); // gas 19170 sun
    }

    function openall() external{
        openFixedRecord();
        if(BetRecordExtend.length > 0)
            openExtendRecord(BetRecordExtend.length);
    }

    function dealTRX(address player, uint256 betValue, uint256 totalValue) internal {
        address(_CoinPool).transfer(betValue);
        if(totalValue > 0)
            _CoinPool.transfer(player, totalValue);
    }

    function dealRTRX(address player, uint256 betValue, uint256 totalValue) internal {
        if (totalValue > betValue){
            player.transferToken(betValue, tokenIdRTRX);
            _CoinPool.transfer(player, totalValue - betValue);
        }else if(totalValue < betValue){
            player.transferToken(totalValue, tokenIdRTRX);
            address(_CoinPool).transferToken(betValue - totalValue, tokenIdRTRX);
        }else{
            player.transferToken(betValue, tokenIdRTRX);
        }
    }

    function openIbet(BetStruct storage ibet, uint256 betNumber, uint256 openNumber) internal returns(uint256,uint256) {
            (address player, uint256 trxvalue, uint256 rtrxvalue, uint256 number, uint32 betType) = decode(ibet.betInfoEn);
            if (number >= block.number)
                return(0, 0);
            if (betNumber != number)
                openNumber = hashNumber(getHashByNumber(number));
            uint256 totalValue;
            if(trxvalue > 0){
                totalValue = isWin(betType, openNumber, trxvalue);
                dealTRX(player, trxvalue, totalValue);
            }
            else{
                totalValue = isWin(betType, openNumber, rtrxvalue);
                dealRTRX(player, rtrxvalue, totalValue);
            }
            //emit openLog(ibet.betInfoEn, totalValue);
            return (number, openNumber);
    }

    function openFixedRecord() public {
        uint256 openNumber;
        uint256 betNumber = 0;
        for(uint256 i = 0; i < BetRecord.length; i++){
            BetStruct storage ibet = BetRecord[i];
            if (ibet.betInfoEn == 0){
                break;
            }
            (betNumber, openNumber) = openIbet(ibet, betNumber, openNumber);
            if (betNumber == 0)
                break;
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
        uint256 openNumber;
        uint256 betNumber = 0;
        for(i = nextOpen; i < end; i++){
            BetStruct storage ibet = BetRecordExtend[i];
            (betNumber, openNumber) = openIbet(ibet, betNumber, openNumber);
            if (betNumber == 0)
                break;
        }
        if (i == BetRecordExtend.length){
            nextOpen = 0;
            delete BetRecordExtend;
        }else{
            nextOpen = i;
        }
    }

    function xopen(uint256 num) public view returns(bytes32 id, bytes32 hashbyte, uint256 number, uint256 openNumber, address player, uint32 betType, uint256 trxvalue, uint256 rtrxvalue, uint256 winvalue){
        return xopenWithHash(num, 0);
    }

    function xopenWithHash(uint256 num, uint256 hashnum) public view returns(bytes32 id, bytes32 hashbyte, uint256 number, uint256 openNumber, address player, uint32 betType, uint256 trxvalue, uint256 rtrxvalue, uint256 winvalue){
        BetStruct memory ibet;
        if (num < BetRecord.length){
            ibet = BetRecord[num];
        }else {
            ibet = BetRecordExtend[num - BetRecord.length];
        }
        return preopenWithHash(ibet.betInfoEn, hashnum);
    }

    function preopenWithHash(uint256 id, uint256 hashnum) public view  returns(bytes32 rid, bytes32 hashbyte, uint256 number, uint256 openNumber, address player, uint32 betType, uint256 trxvalue, uint256 rtrxvalue, uint256 winvalue){
        (player, trxvalue, rtrxvalue, number, betType) = decode(id);
        if(hashnum > 0)
            hashbyte = bytes32(hashnum);
        if(uint256(hashbyte) == 0)
            hashbyte = blockhash(number);
        if(uint256(hashbyte) == 0)
            hashbyte == Hashes[number];
        openNumber = hashNumber(hashbyte);
        winvalue = isWin(betType, openNumber, trxvalue>0?trxvalue:rtrxvalue);
        rid = bytes32(id);
    }

    function preopen(uint256 id) public view  returns(bytes32 rid, bytes32 hashbyte, uint256 number, uint256 openNumber, address player, uint32 betType, uint256 trxvalue, uint256 rtrxvalue, uint256 winvalue){
        return preopenWithHash(id, 0);
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

    function balanceTRX() external view returns(uint256){
        return address(this).balance;
    }
    function balanceToken(uint256 token) external view returns(uint256){
        return address(this).tokenBalance(token);
    }

    function gbetNum() external view returns(uint256, uint256){
        uint256 n = 0;
        for(uint256 i = 0; i < BetRecord.length; i++){
            if (BetRecord[i].betInfoEn == 0)
                break;
            n++;
        }
        return (n+BetRecordExtend.length, n+BetRecordExtend.length-nextOpen);
    }

    function gblockhash(uint256 number) public view returns (bytes32, bytes32, uint256){
        return (blockhash(number), Hashes[number], number);
    }

    function curblock() public view returns (bytes32, bytes32, uint256){
        return gblockhash(block.number-1);
    }
}