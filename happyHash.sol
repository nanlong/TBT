pragma solidity >=0.4.0;

import "./Game.sol";

contract HappyHash is Game{
    constructor(string _name, address pool) Game(_name,pool) public{}

    function nwin() public view returns(bool, uint256, bytes32, uint256, bytes32) {
        BetStruct storage ibet = BetRecord[0];
        (uint256 trxvalue, uint256 rtrxvalue, uint256 number, uint256 betType) = decode(ibet.betInfoEn);
        uint256 bhash = uint256(blockhash(number));
        while ((bhash & 0xf) >= 10) {
            bhash >>= 4;
        }
        uint256 offset = (bhash&0xf)*8;
        if (((betType>>offset)&0xff)==0)
            return (false, 10000, blockhash(number), bhash&0xf,blockhash(number));
        uint256 n = 0;
        for(uint256 i = 0; i < 10; i++){
            if (betType&0xff > 0)
                n++;
            betType>>=8;
        }
        return (n>0, n, blockhash(number), bhash&0xf,blockhash(number));
    }
    // 返回: (输赢,注数)
    function isWin(uint256 betType, uint256 betHash) internal pure returns (bool, uint256) {
        while ((betHash & 0xf) >= 10) {
            betHash >>= 4;
        }
        uint256 offset = (betHash&0xf)*8;
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
}