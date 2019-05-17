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
        address player; // 下注者
        uint256 betInfoEn; //
    }
    event betLog(address player, uint256 betType, uint256 betValue, uint256 tokenValue);
    event openLog(address player, uint256 betType, uint256 betValue, uint256 tokenValue, bool win);
    uint256 public nextOpen;
    bool public opening;
    BetStruct[] public BetRecord;

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
    function encode(uint256 trxvalue, uint256 rtrxvalue, uint256 number,uint256 betType)internal pure returns(uint256){
        require(trxvalue < (1<<(8*8)) && rtrxvalue < (1<<(8*8)) && number < (1<<(13*8)));
        uint256 value = trxvalue;
        uint256 flag = 0;
        if (rtrxvalue > 0) {
            value = rtrxvalue;
            flag = 1<<((8)*8);
        }
        return betType<<(22*8)|number<<(9*8)|flag|value;
    }
    function decode(uint256 en) internal pure returns(uint256 trxvalue, uint256 rtrxvalue, uint256 number,uint256 betType){
        trxvalue = rtrxvalue = 0;
        if ((en & (1<<(8*8))) > 0)
            rtrxvalue = en & ((1<<(8*8))-1);
        else
            trxvalue = en & ((1<<(8*8))-1);
        number = (en >> (9*8))& ((1<<(13*8))-1);
        betType = en >> (22*8);
    }
    function bet(uint256 betType) external payable gameOpened{
        if (msg.tokenid == tokenIdRTRX){
            require(msg.tokenvalue >= 20e6 && msg.tokenvalue < address(_CoinPool).balance/10);
            _CoinPool.transferTBT(msg.sender, msg.tokenvalue*1e9); // big gas 352110 sun
        }else{
            require(msg.value >= 20e6 && msg.value < address(_CoinPool).balance/10);
            _CoinPool.transferTBT(msg.sender, msg.value*1e9); // big gas
        }

        uint256 last = BetRecord.length;
        BetRecord.length++;
        BetStruct storage ibet = BetRecord[last];
        ibet.player = msg.sender;
        ibet.betInfoEn = encode(msg.value, msg.tokenvalue, block.number, betType); // encode: small gas 3820 sun
        emit betLog(ibet.player, betType, msg.value, msg.tokenvalue); // gas 19170 sun
    }

    function openall() external{
        open(BetRecord.length);
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

    function open(uint256 num) public{
        require(BetRecord.length > 0);
        uint256 end = num+nextOpen;
        if (end > BetRecord.length)
            end = BetRecord.length;
        uint256 i = 0;
        uint256 betHash;
        uint256 betNumber = 0;
        for(i = nextOpen; i < end; i++){
            BetStruct storage ibet = BetRecord[i];
            (uint256 trxvalue, uint256 rtrxvalue, uint256 number, uint256 betType) = decode(ibet.betInfoEn);
            if (number >= block.number)
                break;
            if (betNumber != number)
                betHash = uint256(blockhash(number));
            (bool win, uint256 n) = isWin(betType, betHash);
            if(trxvalue > 0)
                dealTRX(ibet.player, trxvalue, win, n);
            else
                dealRTRX(ibet.player, rtrxvalue, win, n);
            emit openLog(ibet.player, betType, trxvalue, rtrxvalue, win);
        }
        if (i == BetRecord.length){
            nextOpen = 0;
            delete BetRecord;
        }else{
            nextOpen = i;
        }
    }

    function xopen(uint256 num) public view returns(string, uint256, bool, uint256){
        BetStruct storage ibet = BetRecord[num];
        (uint256 trxvalue, uint256 rtrxvalue, uint256 number, uint256 betType) = decode(ibet.betInfoEn);
        uint256 betHash = uint256(blockhash(number));
        (bool win, uint256 n) = isWin(betType, betHash);
        if(win){
            if(trxvalue > 0){
                return ("win trxvalue", trxvalue*970/100/n, win, n);
            }else{
                return ("win trc10", rtrxvalue*970/100/n, win, n);
            }
        }else{
            if(trxvalue > 0){
                return ("lose trxvalue", rtrxvalue, win, n);
            }else{
                return ("lose trc10", rtrxvalue, win, n);
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