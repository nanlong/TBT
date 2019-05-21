pragma solidity >=0.4.0;

import "game.sol";

contract HappyScratch is Game{
    constructor(string _name, address pool) Game(_name,pool) public{}
    // 返回: (输赢,注数)
    function isWin(uint32 betType, uint256 openNumber, uint256 betValue) internal pure returns (uint256 totalValue) {
        return (betValue * openNumber * 90) / (50*100); // betValue*(openNumber/50)*0.9
    }
    function hashNumber(bytes32 betHash) internal pure returns(uint256 number){
        uint256 _hash = uint256(betHash);
        while ((_hash & 0xf) >= 10) {
            _hash >>= 4;
        }
        number = _hash&0xf;
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