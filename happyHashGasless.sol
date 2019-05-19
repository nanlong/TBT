pragma solidity >=0.4.0;

import "game.sol";

contract HappyHash is Game{
    constructor(string _name, address pool) Game(_name,pool) public{}

    function nwin(uint256 num) public view returns(bool, uint256, bytes32, uint256) {
        BetStruct storage ibet = BetRecord[num];
        (address player, uint256 trxvalue, uint256 rtrxvalue, uint256 number, uint256 betType) = decode(ibet.betInfoEn);
        uint256 betHash = uint256(blockhash(number));
        while ((betHash & 0xf) >= 10) {
            betHash >>= 4;
        }
        uint256 winFlag = 1<<(betHash&0xf);
        if ((betType & winFlag)==0)
            return (false, 0, blockhash(number), betHash&0xf);
        uint256 n = 0;
		while (betType > 0) {
			n++;
			betType &= betType - 1;
		}
        return (n>0, n, blockhash(number), betHash&0xf);
    }
    // 返回: (输赢,注数)
    function isWin(uint256 betType, uint256 betHash) internal pure returns (bool, uint256) {
        while ((betHash & 0xf) >= 10) {
            betHash >>= 4;
        }
        uint256 winFlag = 1<<(betHash&0xf);
        if ((betType & winFlag)==0)
            return (false, 0);
        uint256 n = 0;
		while (betType > 0) {
			n++;
			betType &= betType - 1;
		}
        return (n > 0, n);
    }
}