pragma solidity >=0.4.0;

import "game.sol";

contract HappyHash is Game{
    constructor(string _name, address pool) Game(_name,pool) public{}

    // 返回: (输赢,注数)
    function isWin(uint32 betType, uint256 openNumber, uint256 betValue) internal pure returns (uint256 totalValue) {
        betType = betType&(0x3ff);
        uint256 winFlag = 1<<(openNumber&0xf);
        if ((betType & winFlag)==0)
            return 0;
        uint256 n = 0;
		while (betType > 0) {
			n++;
			betType &= betType - 1;
		}
        return n>0 ? betValue*(97*10)/100/n : 0;
    }

    function hashNumber(bytes32 betHash) internal pure returns(uint256 number){
        number = uint256(betHash);
        while ((number & 0xf) >= 10) {
            number >>= 4;
        }
        return number&0xf;
    }

    function bet(uint32 betType) external payable{
        tibet(betType);
    }
}

contract HappyHash16 is Game{
    constructor(string _name, address pool) Game(_name,pool) public{}

    // 返回: (输赢,注数)
    function isWin(uint32 betType, uint256 openNumber, uint256 betValue) internal pure returns (uint256 totalValue) {
        betType = betType&(0xffff);
        uint256 winFlag = 1<<(openNumber&0xf);
        if ((betType & winFlag)==0)
            return 0;
        uint256 n = 0;
		while (betType > 0) {
			n++;
			betType &= betType - 1;
		}
        return n>0 ? betValue*(97*16)/100/n : 0;
    }

    function hashNumber(bytes32 betHash) internal pure returns(uint256 number){
        return uint256(betHash)&0xf;
    }

    function bet(uint32 betType) external payable{
        tibet(betType);
    }
}