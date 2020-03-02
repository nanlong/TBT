pragma solidity >=0.4.0;

contract Game{
    //function bet(uint8 value, bool up, string seed, address[] ref) public payable returns(bool,uint8);
    function bet(string memory name) public payable  returns(bytes4, bytes memory);
}

contract Attack{
    Game public game;
    constructor(Game _game)public{
        game = _game;
    }
    function balance(address dest) public view returns(uint256, uint256){
        return (address(this).balance, dest.balance);
    }
    function bet(string memory name) public payable  returns(bytes4, bytes memory){
        bool ret;
        bytes memory rb;
        (ret,rb) = address(game).call.value(msg.value)(msg.data); // call.value().gas()(param)
        return abi.decode(rb, (bytes4, bytes));
    }
}