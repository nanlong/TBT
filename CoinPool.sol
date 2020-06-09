pragma solidity >=0.4.0;

contract TRC20 {
    mapping (address => uint256) public balanceOf;
    function transfer(address to, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);
}

contract Game{
    function update() public;
    function updateCoinPool() external;
}

contract CoinPool{
    enum GameStatus{NONE,CLOSE,OPEN}
    // 资金池总开关. true:表示打开, false:表示锁定.
    // 锁定状态下所有Game都无法动用资金. owner提现不受限制.
    bool public opening;
    bool public isActive;

    // owner 合约拥有者, 拥有合约所有的权限. owner为合约创建者, 暂不支持更改.
    // 一定要保存好owner的私钥, 做好备份并禁止泄露.
    address payable public  owner;
    // key:游戏合约地址
    // value:是否允许动用资金 true:允许 false:禁止
    mapping(address=>GameStatus) public games;
    Game[] public gamelist;
    // 杠杆比率, 即游戏合约转账必须满足 transferAmount * leverRadio <= poolBalance
    // 比如资金池资金(poolBalance)=100, 杠杆比率(leverRadio)=10, 则游戏合约每次最多只能转账(transferAmount) = 10
    // 如果超过这个限度, 则转账失败, 不会发生任何的资金变动.
    uint256 public leverRadio;
 
    uint256 public tokenIdRLBT;
    uint256 public tokenIdLBT;
    uint256 public tokenIdTG;

    CoinPool public preCoinPool;
    CoinPool public nextCoinPool;

    // onlyOnwer 表示只有owner才可以调用此方法
    modifier onlyOwner(){require(msg.sender==owner, "onlyOwner");_;}
    // mustOpen 表示只有资金池处于打开状态, 并且对应的game允许动用资金, 才可以通过
    modifier onlyGamer(){require(opening==true&&games[msg.sender]==GameStatus.OPEN, "onlyGamer");_;}

    modifier onlyCoinpool(){require(msg.sender==address(nextCoinPool), "onlyCoinpool");_;}

    // 创建合约,设置owner为创建者
    // 权限: 无
    // 参数: _openning 资金池状态
    //      _leverRadio 资金比率
/*
    constructor(CoinPool prePool, Game profit, bool _openning, uint256 _leverRadio, TRC20 _tbt, uint256 TBS_ID, uint256 RTRX_ID) public{
        preCoinPool = prePool;
        profitContract = profit;
        owner = msg.sender;
        opening = _openning;
        leverRadio = _leverRadio;
        tbt = _tbt;
        tokenIdRTRX = RTRX_ID;
        tokenIdTBS = TBS_ID;
    }
*/

    constructor(CoinPool prePool, uint256 lbt, uint256 rlbt, uint256 tg) public {
        preCoinPool = prePool;
        owner = preCoinPool.owner();
        nextCoinPool = CoinPool(owner);
        opening = true;
        tokenIdLBT = lbt;
        tokenIdRLBT = rlbt;
        tokenIdTG = tg;
        isActive = true;
    }

    /* ------------------------------[Only Coinpool!]------------------------------- */

    /* ------------------------------[Only Owner!]------------------------------- */

    function switchCoinpool(CoinPool pool) public onlyOwner{
        nextCoinPool = pool;
    }

    function switchRLBT(uint256 token) public onlyOwner{
        tokenIdRLBT = token;
    }

    function switchTG(uint256 token)public onlyOwner{
        tokenIdTG = token;
    }

    function switchLBT(uint256 token)public onlyOwner{
        tokenIdLBT = token;
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
        justOpenGameUnsafe(_game);
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

    function justOpenGameUnsafe(Game _game) internal onlyOwner{
        require(address(_game) != address(this), "game this check");
        games[address(_game)] = GameStatus.OPEN;
    }

    function justOpenGame(Game _game) public onlyOwner{
        require(games[address(_game)]!=GameStatus.NONE, "game not exist");
        justOpenGameUnsafe(_game);
    }
    function justStopGame(Game _game) public onlyOwner{
        require(games[address(_game)]!=GameStatus.NONE, "game not exist");
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
        msg.sender.transfer(_amount);
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
    function transfer(address payable to, uint256 _amount) external onlyGamer{
        // 转账金额不可超过一定比率
        require(_amount * leverRadio < address(this).balance, "transfer ratio check");
        to.transfer(_amount);
    }

    // 转账, 转账trc10到指定地址, 由Game合约调用, 当玩家胜利后, Game合约调用此方法发起转账
    // 权限: gamer
    // 参数: tokenID token的ID
    //      to 提现地址
    //      _amount 转账金额
    function transferToken(address payable to, uint256 _amount, uint256 tokenID) external onlyGamer{
        to.transferToken(_amount, tokenID);
    }

    /* ------------------------------[Only View!]------------------------------- */

    function gameCount() external view returns(uint256){
        return gamelist.length;
    }

    function isOpen() external view returns(bool){
        return opening && games[msg.sender]==GameStatus.OPEN;
    }

    function balanceTRX() public view returns(uint256){
        return address(this).balance;
    }
    function balanceToken(uint256 token) public view returns(uint256){
        return address(this).tokenBalance(token);
    }

    /* ------------------------------[Only Profit!]------------------------------- */

    /* ------------------------------[Only Deposit!]------------------------------- */

    // 充值, 向合约转账即表示向合约充值. 玩家失败后, 或者想增加资金数, 由此向合约充值.
    // 权限: 无
    function()external payable{}
}