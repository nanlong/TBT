pragma solidity >=0.4.0;

contract TRC20 {
    function transfer(address to, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);
}

contract Game{
    string public name;
    function update() public;
}

contract CoinPool{
    enum GameStatus{NONE,CLOSE,OPEN}
    // owner 合约拥有者, 拥有合约所有的权限. owner为合约创建者, 暂不支持更改.
    // 一定要保存好owner的私钥, 做好备份并禁止泄露.
    address public  owner;
    // 资金池总开关. true:表示打开, false:表示锁定.
    // 锁定状态下所有Game都无法动用资金. owner提现不受限制.
    bool public opening;
    // key:游戏合约地址
    // value:是否允许动用资金 true:允许 false:禁止
    mapping(address=>GameStatus) public games;
    Game[] public gamelist;
    // 杠杆比率, 即游戏合约转账必须满足 transferAmount * leverRadio <= poolBalance
    // 比如资金池资金(poolBalance)=100, 杠杆比率(leverRadio)=10, 则游戏合约每次最多只能转账(transferAmount) = 10
    // 如果超过这个限度, 则转账失败, 不会发生任何的资金变动.
    uint256 public leverRadio;

    TRC20 public tbt;
    uint256 public tokenIdRTRX;
    uint256 public tokenIdTBS;

    // onlyOnwer 表示只有owner才可以调用此方法
    modifier onlyOwner(){require(msg.sender==owner);_;}
    // mustOpen 表示只有资金池处于打开状态, 并且对应的game允许动用资金, 才可以通过
    modifier onlyGamer(){require(opening==true&&games[msg.sender]==GameStatus.OPEN);_;}

    // 创建合约,设置owner为创建者
    // 权限: 无
    // 参数: _openning 资金池状态
    //      _leverRadio 资金比率
    constructor(bool _openning, uint256 _leverRadio, TRC20 _tbt, uint256 TBS_ID, uint256 RTRX_ID) public{
        owner = msg.sender;
        opening = _openning;
        leverRadio = _leverRadio;
        tbt = _tbt;
        tokenIdRTRX = RTRX_ID;
        tokenIdTBS = TBS_ID;
    }

    /* ------------------------------[Only Owner!]------------------------------- */

    function switchTBT(TRC20 _tbt) public onlyOwner{
        tbt = _tbt;
    }

    function switchRTRX(uint256 token)public onlyOwner{
        tokenIdRTRX = token;
    }

    function switchTBS(uint256 token)public onlyOwner{
        tokenIdTBS = token;
    }
    
    function update(uint256 start, uint256 end) public onlyOwner {
        for(uint256 i = start; i < end; i++){
            gamelist[i].update();
        }
    }

    function updateAll() public onlyOwner{
        update(0, gamelist.length);
    }

    // 增加游戏合约地址,增加后该合约即可以使用资金(在资金池解锁的状态下)
    // 权限: owner
    // 参数: _game 游戏合约地址
    function addGameWithUpdate(Game _game) external onlyOwner{
        if(games[address(_game)] == GameStatus.NONE)
            gamelist.push(_game);
        justOpenGame(_game);
        _game.update();
    }
    // 停止某个游戏合约, 停止后该合约即无法使用资金
    // 权限: owner
    // 参数: _game 停止的游戏合约地址
    function stopGameWithUpdate(Game _game) external onlyOwner{
        justStopGame(_game);
        _game.update();
    }

    // 冻结资金池, 所有的游戏均无法使用资金
    // 权限: owner
    function lockWithUpdate() external onlyOwner{
        justLock();
        updateAll();
    }
    // 解锁资金池
    // 权限: owner
    function unlockWithUpdate() external onlyOwner{
        justUnlock();
        updateAll();
    }

    function justOpenGame(Game _game) public onlyOwner{
        games[address(_game)] = GameStatus.OPEN;
    }
    function justStopGame(Game _game) public onlyOwner{
        games[address(_game)] = GameStatus.CLOSE;
    }
    function justLock() public onlyOwner{
        opening = false;
    }
    function justUnlock() public onlyOwner{
        opening = true;
    }

    // 修改资金比率
    // 权限: owner
    // 参数: _leverRadio 新比率
    function changeLeverRadio(uint256 _leverRadio) external onlyOwner{
        leverRadio = _leverRadio;
    }

    // 提现到owner
    // 权限: owner
    // 参数: _amount 提现金额, 如果提现金额比资金池大, 则提走全部资金 
    function withdraw(uint256  _amount) external onlyOwner{
        owner.transfer(_amount);
    }

    function withdrawToken(uint256 _amount, uint256 tokenID) external onlyOwner {
        msg.sender.transferToken(_amount, tokenID);
    }

    function withdrawTRC20(address trc, uint256 _amount) external onlyOwner {
        TRC20(trc).transfer(msg.sender, _amount);
    }

    /* ------------------------------[Only Gamer!]------------------------------- */

    // 转账, 转账资金到指定地址, 由Game合约调用, 当玩家胜利后, Game合约调用此方法发起转账
    // 权限: gamer
    // 参数: to 提现地址
    //      _amount 转账金额
    function transfer(address  to, uint256 _amount) external onlyGamer{
        // 转账金额不可超过一定比率
        require(_amount * leverRadio < address(this).balance);
        to.transfer(_amount);
    }

    // 转账, 转账trc10到指定地址, 由Game合约调用, 当玩家胜利后, Game合约调用此方法发起转账
    // 权限: gamer
    // 参数: tokenID token的ID
    //      to 提现地址
    //      _amount 转账金额
    function transferToken(address  to, uint256 _amount, uint256 tokenID) external onlyGamer{
        to.transferToken(_amount, tokenID);
    }

    function transferTRC20(address to, uint256 _amount, address trc20) external onlyGamer{
        TRC20(trc20).transfer(to, _amount);
    }

    function transferTBTAndTBS(address to,uint256 _TBT, uint256 _TBS) external onlyGamer{
        //tbt.transferFrom(owner, to, _TBT);
        tbt.transfer(to, _TBT);
        to.transferToken(_TBS, tokenIdTBS);
    }

    /* ------------------------------[Only View!]------------------------------- */

    function gameCount() external view returns(uint256){
        return gamelist.length;
    }

    function isOpen() external view returns(bool){
        return opening && games[msg.sender]==GameStatus.OPEN;
    }

    function balanceTRX() external view returns(uint256){
        return address(this).balance;
    }
    function balanceToken(uint256 token) external view returns(uint256){
        return address(this).tokenBalance(token);
    }

    /* ------------------------------[Only Deposit!]------------------------------- */

    // 充值, 向合约转账即表示向合约充值. 玩家失败后, 或者想增加资金数, 由此向合约充值.
    // 权限: 无
    function()external payable{}
}