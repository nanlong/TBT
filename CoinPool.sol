pragma solidity >=0.4.0;

contract TRC20 {
    function transfer(address to, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);
}

contract CoinPool{
    // owner 合约拥有者, 拥有合约所有的权限. owner为合约创建者, 暂不支持更改.
    // 一定要保存好owner的私钥, 做好备份并禁止泄露.
    address public  owner;
    // 资金池总开关. true:表示打开, false:表示锁定.
    // 锁定状态下所有Game都无法动用资金. owner提现不受限制.
    bool public openning;
    // key:游戏合约地址
    // value:是否允许动用资金 true:允许 false:禁止
    mapping(address=>bool) public games;
    // 杠杆比率, 即游戏合约转账必须满足 transferAmount * leverRadio <= poolBalance
    // 比如资金池资金(poolBalance)=100, 杠杆比率(leverRadio)=10, 则游戏合约每次最多只能转账(transferAmount) = 10
    // 如果超过这个限度, 则转账失败, 不会发生任何的资金变动.
    uint256 public leverRadio;

    TRC20 public tbt;

    // onlyOnwer 表示只有owner才可以调用此方法
    modifier onlyOwner(){require(msg.sender==owner);_;}
    // mustOpen 表示只有资金池处于打开状态, 并且对应的game允许动用资金, 才可以通过
    modifier onlyGamer(){require(openning==true&&games[msg.sender]==true);_;}

    function swithcTBT(TRC20 _tbt) public onlyOwner{
        tbt = _tbt;
    }

    // 创建合约,设置owner为创建者
    // 权限: 无
    // 参数: _openning 资金池状态
    //      _leverRadio 资金比率
    constructor(bool _openning, uint256 _leverRadio, TRC20 _tbt) public{
        owner = msg.sender;
        openning = _openning;
        leverRadio = _leverRadio;
        tbt = _tbt;
    }
    // 增加游戏合约地址,增加后该合约即可以使用资金(在资金池解锁的状态下)
    // 权限: owner
    // 参数: _game 游戏合约地址
    function addGame(address _game) external onlyOwner{
        games[_game] = true;
    }
    // 停止某个游戏合约, 停止后该合约即无法使用资金
    // 权限: owner
    // 参数: _game 停止的游戏合约地址
    function stopGame(address _game) external onlyOwner{
        games[_game] = false;
    }

    // 冻结资金池, 所有的游戏均无法使用资金
    // 权限: owner
    function lock() external onlyOwner{
        openning = false;
    }
    // 解锁资金池
    // 权限: owner
    function unlock() external onlyOwner{
        openning = true;
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

    function transferTBT(address to,uint256 _amount) external onlyGamer{
        tbt.transferFrom(owner, to, _amount);
    }

    // 充值, 向合约转账即表示向合约充值. 玩家失败后, 或者想增加资金数, 由此向合约充值.
    // 权限: 无
    function()payable external{}
}