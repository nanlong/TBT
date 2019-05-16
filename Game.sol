pragma solidity >=0.4.0;
contract CoinPool{
    function transfer(address to, uint256 _amount) external;
    function transferTBT(address to,uint256 _amount)external;
    function ()payable external;
}

contract Game{
    address public owner;
    CoinPool public  _CoinPool;
    uint256 public tokenIdRTRX;
    struct BetStruct {
        address player; // 下注者
        uint256 blockNumber; // 下注区块号
        uint256 betType; // 0-9: bet0~bet9 10:small 11:big 12:even 13:odd
        uint256 tokenValue; // 下注金额
        uint256 betValue; // 下注金额
    }
    event betLog(address player, uint256 betType, uint256 betValue, uint256 tokenValue);
    event openLog(address player, uint256 betType, uint256 betValue, uint256 tokenValue, bool win);
    uint256 public nextOpen;
    BetStruct[] public BetRecord;

    modifier onlyOwner(){require(msg.sender==owner);_;}
    constructor(address pool, uint256 tokenID)public{
        owner = msg.sender;
        _CoinPool = CoinPool(pool);
        nextOpen = 0;
        tokenIdRTRX = tokenID;
    }
    function switchCoinPool(address pool) external onlyOwner{
        _CoinPool = CoinPool(pool);
    }
    function switchTokenID(uint256 tokenID) external onlyOwner{
        tokenIdRTRX = tokenID;
    }
    function bet(uint256 betType) external payable{
        if (msg.tokenid == tokenIdRTRX){
            require(msg.tokenvalue >= 20e6 && msg.tokenvalue < address(_CoinPool).balance/10);
            _CoinPool.transferTBT(msg.sender, msg.tokenvalue*1e9);
        }else{
            require(msg.value >= 20e6 && msg.value < address(_CoinPool).balance/10);
            _CoinPool.transferTBT(msg.sender, msg.value*1e9);
        }

        uint256 last = BetRecord.length;
        BetRecord.length++;
        BetStruct storage ibet = BetRecord[last];
        ibet.blockNumber = block.number;
        ibet.betType = betType;
        ibet.betValue = msg.value;
        ibet.player = msg.sender;
        ibet.tokenValue = msg.tokenvalue;
        emit betLog(ibet.player, ibet.betType, ibet.betValue, ibet.tokenValue);
    }

    // 返回: (输赢,注数)
    function isWin(BetStruct storage ibet) private view returns (bool, uint256) {
        uint256 bhash = uint256(blockhash(ibet.blockNumber));
        while ((bhash & 0xf) >= 10) {
            bhash >>= 4;
        }
        uint256 betType = ibet.betType;
        uint256 offset = (bhash&0xf)*8;
        if (((betType>>offset)&0xff)==0)
            return (false, 0);
        uint256 n = 0;
        for(uint256 i = 0; i < 10; i++){
            if (betType&0xff > 0)
                n++;
            betType>>=8;  
        }
        return (n > 0, n);
    }

    function openall() external{
        open(BetRecord.length);
    }

    function dealTRX(BetStruct storage ibet, bool win, uint256 n) internal {
        if (!win){ // loose, transfer TRX to coinpool
            address(_CoinPool).transfer(ibet.betValue);
            return;
        }
        uint256 total = ibet.betValue*970/100/n;
        if (total > ibet.betValue){
            ibet.player.transfer(ibet.betValue);
            _CoinPool.transfer(ibet.player, total - ibet.betValue);
        }else{
            ibet.player.transfer(total);
            address(_CoinPool).transfer(ibet.betValue-total);
        }
    }

    function dealRTRX(BetStruct storage ibet, bool win, uint256 n) internal {
        if (!win){ // loose, transfer RTRX to coinpool
            address(_CoinPool).transferToken(ibet.tokenValue, tokenIdRTRX);
            return;
        }
        uint256 total = ibet.tokenValue*970/100/n;
        if (total > ibet.tokenValue){
            ibet.player.transferToken(ibet.tokenValue, tokenIdRTRX);
            _CoinPool.transfer(ibet.player, total - ibet.tokenValue);
        }else{
            ibet.player.transferToken(ibet.tokenValue, total);
            address(_CoinPool).transferToken(total-ibet.tokenValue, tokenIdRTRX);
        }
    }

    function open(uint256 num) public{
        require(BetRecord.length > 0 && BetRecord[0].blockNumber < block.number);
        uint256 end = num+nextOpen;
        if (end > BetRecord.length)
            end = BetRecord.length;
        uint256 i = 0;
        for(i = nextOpen; i < end; i++){
            BetStruct storage ibet = BetRecord[i];
            if (ibet.blockNumber >= block.number)
                break;

            (bool win, uint256 n) = isWin(ibet);
            if(ibet.betValue > 0)
                dealTRX(ibet, win, n);
            else
                dealRTRX(ibet, win, n);
            emit openLog(ibet.player, ibet.betType, ibet.betValue, ibet.tokenValue, win);
        }
        if (i == BetRecord.length){
            nextOpen = 0;
            delete BetRecord;
        }else{
            nextOpen = i;
        }
    }

    function nwin() public view returns(bool, uint256, bytes32, uint256, bytes32) {
        BetStruct storage ibet = BetRecord[0];
        uint256 bhash = uint256(blockhash(ibet.blockNumber));
        while ((bhash & 0xf) >= 10) {
            bhash >>= 4;
        }
        uint256 betType = ibet.betType;
        uint256 offset = (bhash&0xf)*8;
        if (((betType>>offset)&0xff)==0)
            return (false, 10000, blockhash(ibet.blockNumber), bhash&0xf,blockhash(ibet.blockNumber));
        uint256 n = 0;
        for(uint256 i = 0; i < 10; i++){
            if (betType&0xff > 0)
                n++;
            betType>>=8;  
        }
        return (n>0, n, blockhash(ibet.blockNumber), bhash&0xf,blockhash(ibet.blockNumber));
    }

    function xopen(uint256 num) public view returns(string, uint256, bool, uint256){
        BetStruct storage ibet = BetRecord[num];
        (bool win, uint256 n) = isWin(ibet);
        if(win){
            if(ibet.betValue > 0){
                return ("win trx", ibet.betValue*970/100/n, win, n);
                //ibet.player.transfer(ibet.betValue);
                //_CoinPool.transfer(ibet.player, ibet.betValue*970/100/n);
            }else{
                return ("win trc10", ibet.tokenValue*970/100/n, win, n);
                //ibet.player.transferToken(ibet.tokenValue, tokenIdRTRX);
                //_CoinPool.transferToken(ibet.player, ibet.tokenValue*970/100/n, tokenIdRTRX);
            }
            //emit openLog(ibet.player, ibet.betType, ibet.betValue, ibet.tokenValue, true);
        }else{
            if(ibet.betValue > 0){
                return ("lose trx", ibet.betValue, win, n);
                //address(_CoinPool).transfer(ibet.betValue);
            }else{
                return ("lose trc10", ibet.tokenValue, win, n);
                //address(_CoinPool).transferToken(ibet.tokenValue, tokenIdRTRX);
            }
            //emit openLog(ibet.player, ibet.betType, ibet.betValue, ibet.tokenValue, false);
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
        return BetRecord.length;
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