pragma solidity >=0.4.0;

import "game.sol";

// 十选一
contract HappyHash is Game{
    constructor(string memory _name, address payable pool) Game(_name,pool) public{}

    // 判断输赢，返回: (输赢,注数)
    function isWin(uint24 betType, uint256 openNumber, uint256 betValue) internal pure returns (uint256 totalValue) {
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
    // 通过区块哈希生成开奖号码
    function hashNumber(bytes32 betHash) internal pure returns(uint256 number){
        number = uint256(betHash);
        while ((number & 0xf) >= 10) {
            number >>= 4;
        }
        return number&0xf;
    }
    // 玩家下注入口
    function bet(uint24 betType) external payable{
        tibet(betType);
    }
}

// 十六选一
contract HappyHash16 is Game{
    constructor(string memory _name, address payable pool) Game(_name,pool) public{}

    // 返回: (输赢,注数)
    function isWin(uint24 betType, uint256 openNumber, uint256 betValue) internal pure returns (uint256 totalValue) {
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

    function bet(uint24 betType) external payable{
        tibet(betType);
    }
}

// 刮刮乐
contract HappyScratch is Game{
    constructor(string memory _name, address payable pool) Game(_name,pool) public{}
    // 返回: (输赢,注数)
    function isWin(uint24 betType, uint256 openNumber, uint256 betValue) internal pure returns (uint256 totalValue) {
        betType;
        return (betValue * openNumber * 90) / (50*100); // betValue*(openNumber/50)*0.9
    }
    function hashNumber(bytes32 betHash) internal pure returns(uint256 number){
        uint256 _hash = uint256(betHash);
        while ((_hash & 0xf) >= 10) {
            _hash >>= 4;
        }
        number = _hash&0xf;
        _hash >>= 4;
        while ((_hash & 0xf) >= 10) {
            _hash >>= 4;
        }
        number += (_hash&0xf)*10;
        return number;
    }
    function bet() external payable{
        tibet(0);
    }
}
