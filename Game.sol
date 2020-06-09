pragma solidity >=0.4.0;

contract CoinPool{
    uint256 public tokenIdRLBT;
    uint256 public tokenIdLBT;
    uint256 public tokenIdTG;
    address public  owner;
    CoinPool public nextCoinPool;
    address public profitContract;
    function isOpen() external view returns(bool);
    function transferToken(address payable to, uint256 _amount, uint256 tokenID) external;
    function ()external payable;
}

contract Game{
    // 判断输赢 返回赢取的总数
    function isWin(uint24 betType, uint256 openNumber, uint256 betValue) internal pure returns (uint256 totalValue);
    // hash 到 number的转换函数
    function hashNumber(bytes32 betHash) internal pure returns(uint256 number);

    string public name;
    address public owner;
    CoinPool public  _CoinPool;
    uint256 public tokenIdRLBT;
    uint256 public tokenIdLBT;
    uint256 public tokenIdTG;

    enum TokenType{
        None, // must have
        LBT,
        RLBT,
        TG
    }
    struct BetInfo{
        address payable player;
        uint32 blockNo;
        uint32 betAmount;
        uint8 tokenType;
        uint24 betType;
    }
    struct BetStruct {
        bytes32 betInfoEn; //
    }
    event betLog(bytes32 id);
    //event openLog(uint256 id, uint256 totalValue);
    uint256 public nextOpen;
    bool public opening;
    BetStruct[] public BetRecordExtend;
    mapping(uint256=>bytes32) public Hashes;
    mapping(uint256=>uint256) public tokenTypeMap;

    modifier onlyCoinPool(){require(msg.sender==address(_CoinPool), "onlyCoinPool");_;}
    modifier onlyOwner(){require(msg.sender==owner, "onlyOwner");_;}
    modifier gameOpened(){require(opening, "onlyOpen");_;}
    constructor(string memory _name, address payable pool)public{
        name = _name;
        _CoinPool = CoinPool(pool);
        update();
        require(msg.sender!=owner, "contract owner check"); // owner不可以创建游戏合约
        nextOpen = 0;
    }
    function () external payable{}
    function update() public {
        owner = _CoinPool.owner();
        tokenIdLBT = _CoinPool.tokenIdLBT();
        tokenIdRLBT = _CoinPool.tokenIdRLBT();
        tokenIdTG = _CoinPool.tokenIdTG();
        tokenTypeMap[tokenIdLBT] = uint256(TokenType.LBT);
        tokenTypeMap[uint256(TokenType.LBT)] = tokenIdLBT;
        tokenTypeMap[tokenIdRLBT] = uint256(TokenType.RLBT);
        tokenTypeMap[uint256(TokenType.RLBT)] = tokenIdRLBT;
        tokenTypeMap[tokenIdTG] = uint256(TokenType.TG);
        tokenTypeMap[uint256(TokenType.TG)] = tokenIdTG;
        opening = _CoinPool.isOpen();
    }
    function switchCoinPool(address payable pool) external onlyOwner{
        _CoinPool = CoinPool(pool);
        update();
    }

    function updateCoinPool() external onlyCoinPool{
        _CoinPool = _CoinPool.nextCoinPool();
        update();
    }

    function FeedHashes(uint256 number, uint256 _hash) external onlyOwner{
        Hashes[number] = bytes32(_hash);
    }

    function getHashByNumberUnsafe(uint256 number) internal view returns (bytes32 _hash){
        _hash = blockhash(number);
        if(uint256(_hash) > 0)
            return _hash;
        _hash = Hashes[number];
    }

    function getHashByNumberSafe(uint256 number)internal view returns (bytes32 _hash){
        _hash = getHashByNumberUnsafe(number);
        require(uint256(_hash) > 0, "hash check");
    }

    function getFreeSlot() internal returns(BetStruct storage ibet){
        BetRecordExtend.length++;
        return BetRecordExtend[BetRecordExtend.length-1];
    }
    function BetInfoEncode(BetInfo memory s) internal pure returns(uint256) {return uint256(s.player)|uint256(s.blockNo)<<160|uint256(s.betAmount)<<192|uint256(s.tokenType)<<224|uint256(s.betType)<<232;}
    function BetInfoDecode(uint256 en) internal pure returns(BetInfo memory) {return BetInfo(address(en),uint32(en>>160),uint32(en>>192),uint8(en>>224),uint24(en>>232));}
    function BetInfoEnCreate(address payable player,uint32 blockNo,uint32 betAmount,uint8 tokenType,uint24 betType) internal pure returns(uint256) {return uint256(player)|uint256(blockNo)<<160|uint256(betAmount)<<192|uint256(tokenType)<<224|uint256(betType)<<232;}
    function BetInfoCreate(address payable player,uint32 blockNo,uint32 betAmount,uint8 tokenType,uint24 betType) internal pure returns(BetInfo memory) {return BetInfo(player,blockNo,betAmount,tokenType,betType);}
    
    function isContract() internal view returns (bool) {
        return tx.origin != msg.sender;
    }

    function tibet(uint24 betType) internal gameOpened{
        if(isContract()){
            openall();
            return;
        }
        uint8 tokenTyp = uint8(tokenTypeMap[msg.tokenid]);
        require(tokenTyp > 0, "only LBT,RLBT,TG");
        uint256 checkTokenID = msg.tokenid;
        if (checkTokenID == tokenIdRLBT)
            checkTokenID = tokenIdLBT;
        require(msg.tokenvalue >= 1e6 && msg.tokenvalue < address(_CoinPool).tokenBalance(checkTokenID)/10, "bet amount check");
        openExtendRecord(1);
        BetStruct storage ibet = getFreeSlot();
        ibet.betInfoEn = bytes32(BetInfoEnCreate(msg.sender, uint32(block.number), uint32(msg.tokenvalue/1e6), tokenTyp, betType)); // encode: small gas 3820 sun
        emit betLog(ibet.betInfoEn); // gas 19170 sun
    }

    function openall() public{
        openExtendRecord(BetRecordExtend.length);
    }

    function dealLGLBT(address payable player, uint256 tokenID, uint256 betValue, uint256 totalValue) internal {
        address(_CoinPool).transferToken(betValue, tokenID);
        if(totalValue > 0)
            _CoinPool.transferToken(player, totalValue, tokenID);
    }

    function dealRLBT(address payable player, uint256 betValue, uint256 totalValue) internal {
        if (totalValue > betValue){
            player.transferToken(betValue, tokenIdRLBT);
            _CoinPool.transferToken(player, totalValue - betValue, tokenIdLBT);
            return;
        }else if(totalValue < betValue){
            player.transferToken(totalValue, tokenIdRLBT);
            address(_CoinPool).transferToken(betValue - totalValue, tokenIdRLBT);
        }else{
            player.transferToken(betValue, tokenIdRLBT);
        }
    }

    function openIbet(BetStruct storage ibet, uint256 betNumber, uint256 openNumber) internal returns(uint256,uint256)  {
            BetInfo memory info = BetInfoDecode(uint256(ibet.betInfoEn));
            if (info.blockNo >= block.number)
                return(0, 0);
            if (betNumber != info.blockNo)
                openNumber = hashNumber(getHashByNumberSafe(info.blockNo));
            uint256 betAmount = info.betAmount * 1e6;
            uint256 totalValue = isWin(info.betType, openNumber, betAmount);
            if(info.tokenType == uint256(TokenType.RLBT))
                dealRLBT(info.player, betAmount, totalValue);
            else
                dealLGLBT(info.player, tokenTypeMap[info.tokenType], betAmount, totalValue);
            //emit openLog(ibet.betInfoEn, totalValue);
            return (info.blockNo, openNumber);
    }

    function openExtendRecord(uint256 num) public{
        if (BetRecordExtend.length == nextOpen)
            return;
        uint256 end = num+nextOpen;
        if (end > BetRecordExtend.length)
            end = BetRecordExtend.length;
        if (end > nextOpen + 100)
            end = nextOpen + 100;
        uint256 i = 0;
        uint256 openNumber;
        uint256 betNumber = 0;
        for(i = nextOpen; i < end; i++){
            BetStruct storage ibet = BetRecordExtend[i];
            if (uint256(ibet.betInfoEn)==0)
                continue;
            (betNumber, openNumber) = openIbet(ibet, betNumber, openNumber);
            if (betNumber == 0)
                break;
        }
        nextOpen = i;
    }

    function openExtendRecordMan(uint256 start, uint256 end) public onlyOwner{
        uint256 openNumber;
        uint256 betNumber = 0;
        for (uint256 i = start; i < end; i++){
            BetStruct storage ibet = BetRecordExtend[i];
            if (uint256(ibet.betInfoEn)==0)
                continue;
            (betNumber, openNumber) = openIbet(ibet, betNumber, openNumber);
            if (betNumber == 0)
                continue;
            delete BetRecordExtend[i];
        }
    }

    function xopen(uint256 num) public view  returns(bytes32 rid, bytes32 hashbyte, uint256 number, uint256 openNumber, address player, uint32 betType, uint256 betAmount, uint256 tokenID, uint256 winvalue){
        return xopenWithHash(num, 0);
    }

    function xopenWithHash(uint256 num, uint256 hashnum) public view  returns(bytes32 rid, bytes32 hashbyte, uint256 number, uint256 openNumber, address player, uint32 betType, uint256 betAmount, uint256 tokenID, uint256 winvalue){
        BetStruct storage ibet = BetRecordExtend[num];
        return preopenWithHash(uint256(ibet.betInfoEn), hashnum);
    }

    function preopenInfoWithHash(BetInfo memory info, uint256 id, uint256 hashnum) internal view returns(bytes32 rid, bytes32 hashbyte, uint256 number, uint256 openNumber, address player, uint24 betType, uint256 betAmount, uint256 tokenID, uint256 winvalue) {
        if(hashnum > 0)
            hashbyte = bytes32(hashnum);
        if(uint256(hashbyte) == 0)
            hashbyte = getHashByNumberUnsafe(info.blockNo);
        player = info.player;
        number = info.blockNo;
        betType = info.betType;
        tokenID = tokenTypeMap[info.tokenType];
        betAmount = info.betAmount*1e6;
        openNumber = hashNumber(hashbyte);
        winvalue = isWin(info.betType, openNumber, betAmount);
        rid = bytes32(id);
    }

    function preopenWithHash(uint256 id, uint256 hashnum) public view returns(bytes32 rid, bytes32 hashbyte, uint256 number, uint256 openNumber, address player, uint32 betType, uint256 betAmount, uint256 tokenID, uint256 winvalue){
        BetInfo memory info = BetInfoDecode(id);
        return preopenInfoWithHash(info, id, hashnum);
    }

    function preopen(uint256 id) public view returns(bytes32 rid, bytes32 hashbyte, uint256 number, uint256 openNumber, address player, uint32 betType, uint256 betAmount, uint256 tokenID, uint256 winvalue){
        return preopenWithHash(id, 0);
    }

    function getMyRecord() public view returns(bytes32 rid, bytes32 hashbyte, uint256 number, uint256 openNumber, address player, uint32 betType, uint256 betAmount, uint256 tokenID, uint256 winvalue){
        if (BetRecordExtend.length > 0){
            uint256 limit = 0;
            if(BetRecordExtend.length > 256)
                limit = BetRecordExtend.length - 256;
            for(uint256 i = BetRecordExtend.length; i > limit; i--){
                uint256 bid = uint256(BetRecordExtend[i-1].betInfoEn);
                BetInfo memory info = BetInfoDecode(bid);
                if (info.player == msg.sender)
                    return preopenInfoWithHash(info, bid, 0);
            }
        }
    }

    function getMyBalance() public view returns(uint256 lbt, uint256 rlbt, uint256 tg) {
        return (msg.sender.tokenBalance(tokenIdLBT), msg.sender.tokenBalance(tokenIdRLBT), msg.sender.tokenBalance(tokenIdTG));
    }

    function withdraw() external onlyOwner {
        msg.sender.transfer(address(this).balance);
    }

    function withdrawToken(uint256 tokenID) external onlyOwner {
        msg.sender.transferToken(address(this).tokenBalance(tokenID), tokenID);
    }

    function balanceTRX() external view returns(uint256){
        return address(this).balance;
    }
    function balanceToken(uint256 token) external view returns(uint256){
        return address(this).tokenBalance(token);
    }

    function gbetNum() external view returns(uint256, uint256){
        return (BetRecordExtend.length, BetRecordExtend.length-nextOpen);
    }

    function gblockhash(uint256 number) public view returns (bytes32, bytes32, uint256){
        return (blockhash(number), Hashes[number], number);
    }

    function curblock() public view returns (bytes32, bytes32, uint256){
        return gblockhash(block.number-1);
    }
}