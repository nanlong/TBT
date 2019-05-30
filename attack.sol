pragma solidity >=0.4.0;

contract Game{
    function bet() external payable;
}

contract Attack{
    Game game;
    constructor(Game _game) public{
        game = _game;
    }
    function attack() external payable {
        game.bet();
    }
}