pragma solidity >=0.4.0;

import "game.sol";

contract LockProfit{

    address public owner;
    CoinPool public  _CoinPool;

    modifier onlyOwner(){require(msg.sender==owner, "onlyOwner");_;}
    modifier gameOpened(){require(opening, "onlyOpened");_;}
    modifier onlyCoinPool(){require(msg.sender==address(_CoinPool), "onlyCoinPool");_;}

    TRC20 public tbt;
    struct Order{
        uint256 amount;
        uint256 time;
    }
    struct UnlockOrderList{
        Order[] orders;
    }
    struct LockOrderList{
        Order[] orders;
    }
    struct WithdrawOrderList{
        uint256 nextDeal;
        //uint256[] orders;
    }
    struct DayProfit{
        int256 totalProfit;
        uint256 totalTBT;
        uint256 blockInfo;
        uint256 sharePercentage;
        mapping(address=>uint256) holders;
    }

    mapping(uint256=>DayProfit) public profitHistory;
    mapping(address=>LockOrderList) lockTBTHistory;
    mapping(address=>UnlockOrderList) unlockTBTHistory;
    mapping(address=>WithdrawOrderList) public withdrawTBTHistory;

    mapping(address=>uint256) public holderTBTAmount;
    uint256 public totalTBT;
    address[] public holdersList;
    bool public isShareExecing;
    uint256 public nextShare;
    uint256 public shareTimestamp;
    uint256 public sharePercentage;
    bool public opening;

    constructor(CoinPool pool, uint256 _percentage) public{
        _CoinPool = pool;
        update();
        require(msg.sender != owner, "contract owner check");
        isShareExecing = false;
        changeSharePercentageUnsafe(_percentage);
    }

    function timeAlign() public view returns(uint256) {
        return timeKey(block.timestamp);
    }

    function timeKey(uint256 time) public pure returns(uint256){
        return time / 1 days * 1 days + 4 hours;
    }

/* ------- holder info ------ */
    // return (holder, holderLength, totalTBT, curProfits,  holder.lockTBT, isSharing), 
    function getHolderInfo(address holder) public view returns (address, uint256, uint256, int256, uint256, bool){
        return (holder, holdersList.length, totalTBT, _CoinPool.getProfits(), holderTBTAmount[holder], isShareExecing);
    }

    function getMyInfo() public view returns (address, uint256, uint256, int256, uint256, bool){
        return getHolderInfo(msg.sender);
    }

    function getInfoByIndex(uint256 holderIndex) public view returns (address, uint256, uint256, int256, uint256, bool){
        address holder = holdersList[holderIndex];
        return getHolderInfo(holder);
    }

/* ------- order info ------ */
    function getOrderInfoByAddress(address holder) public view returns(address, uint256, uint256, uint256) {
        return (holder, lockTBTHistory[holder].orders.length, unlockTBTHistory[holder].orders.length, withdrawTBTHistory[holder].nextDeal);
    }

    function getMyOrderInfo() public view returns(address, uint256, uint256, uint256){
        return getOrderInfoByAddress(msg.sender);
    }

    function getOrderInfoByIndex(uint256 holderIndex) public view returns(address, uint256, uint256, uint256){
        address holder = holdersList[holderIndex];
        return getOrderInfoByAddress(holder);
    }

/* ------- order detail ---------*/
    function getHistoryOrder(address holder, uint256 orderIndex, bool isLockOrder) public view returns(uint256, uint256){
        Order[] storage orders = unlockTBTHistory[holder].orders;
        if(isLockOrder)
            orders = lockTBTHistory[holder].orders;
        return (orders[orderIndex].amount, orders[orderIndex].time);
    }

    function getMyHistoryOrder(uint256 orderIndex, bool isLockOrder) public view returns(uint256, uint256){
        return getHistoryOrder(msg.sender, orderIndex, isLockOrder);
    }

    function getHistoryOrderByIndex(uint256 holderIndex, uint256 orderIndex, bool isLockOrder) public view returns(uint256, uint256){
        address holder = holdersList[holderIndex];
        return getHistoryOrder(holder, orderIndex, isLockOrder);
    }

/* ------- profit info ------ */

    function queryHistoryProfitByTime(address holder, uint256 time) public view returns(int256, uint256, uint256, uint256, uint256){
        DayProfit storage dayProfit = profitHistory[timeKey(time)];
        return (dayProfit.totalProfit, dayProfit.totalTBT, dayProfit.blockInfo, dayProfit.sharePercentage,dayProfit.holders[holder]);
    }

    function queryMyHistoryProfitByTime(uint256 time) public view returns(int256, uint256, uint256, uint256, uint256){
        return queryHistoryProfitByTime(msg.sender, time);
    }

    function queryHistoryLockInfoByIndex(uint256 index, uint256 time) public view returns(int256, uint256, uint256, uint256, uint256){
        address holder = holdersList[index];
        return queryHistoryProfitByTime(holder, time);
    }
/* ------ only owner -----*/
    function changeSharePercentageUnsafe(uint256 _percentage) internal {
        require(_percentage <= 100, "_percentage check");
        sharePercentage = _percentage;
    }
    function changeSharePercentage(uint256 _percentage) external onlyOwner{
        changeSharePercentageUnsafe(_percentage);
    }

    function updateCoinPool() external onlyCoinPool{
        _CoinPool = _CoinPool.nextCoinPool();
        update();
    }

    function update() public {
        owner = _CoinPool.owner();
        tbt = _CoinPool.tbt();
        opening = _CoinPool.isOpen();
    }

    function switchCoinPool(address pool) external onlyOwner{
        _CoinPool = CoinPool(pool);
        update();
    }

/* ------ rw logic ------ */

    function appendOrder(Order[] storage orders, uint256 tbtAmount) internal {
        orders.length++;
        Order storage order = orders[orders.length-1];
        order.time = block.timestamp;
        order.amount = tbtAmount;
    }

    function lockTBTToOther(address holder, uint256 tbtAmount) public gameOpened{
        require(isShareExecing == false, "lockTBTToOther share check");
        tbt.transferFrom(msg.sender, address(this), tbtAmount);
        Order[] storage orders = lockTBTHistory[holder].orders;
        if (orders.length == 0)
            holdersList.push(holder);
        appendOrder(orders, tbtAmount);
        totalTBT += tbtAmount;
        holderTBTAmount[holder] += tbtAmount;
    }

    function lockTBT(uint256 tbtAmount) public{
        lockTBTToOther(msg.sender, tbtAmount);
    }

    function unlockTBT(uint256 tbtAmount) public gameOpened {
        require(isShareExecing == false, "unlockTBT share check");
        require(holderTBTAmount[msg.sender] >= tbtAmount, "unlockTBT check");
        Order[] storage orders = unlockTBTHistory[msg.sender].orders;
        appendOrder(orders, tbtAmount);
        totalTBT -= tbtAmount;
        holderTBTAmount[msg.sender] -= tbtAmount;
    }

    function withdrawLimitedTBT(uint256 n) public gameOpened {
        if(n > 100) n = 100;
        Order[] storage unlockOrders = unlockTBTHistory[msg.sender].orders;
        WithdrawOrderList storage withdraw = withdrawTBTHistory[msg.sender];
        uint256 end = withdraw.nextDeal + n;
        if(end > unlockOrders.length)
            end = unlockOrders.length;
        uint256 i;
        for(i = withdraw.nextDeal; i < end; i++){
            Order storage order = unlockOrders[i];
            if(order.time + 1 days >= block.timestamp)
                break;
            tbt.transfer(msg.sender, order.amount);
        }
        if (i != withdraw.nextDeal)
            withdraw.nextDeal = i;
    }

    function widthdrawAllTBT() public {
        withdrawLimitedTBT(unlockTBTHistory[msg.sender].orders.length);
    }

    function DoShareProfitStart() public gameOpened {
        require(shareTimestamp + 23 hours < timeAlign(), "DoProfitStart replay check");
        require(isShareExecing == false, "DoProfitStart share check");
        require(block.timestamp >= timeAlign(), "DoProfitStart time check");
        shareTimestamp = timeAlign();
        isShareExecing = true;
        nextShare = 0;
        DayProfit storage dayProfit = profitHistory[shareTimestamp];
        require(dayProfit.totalProfit == 0, "DoProfitStart collision check");
        dayProfit.totalProfit = _CoinPool.getProfits();
        if(dayProfit.totalProfit > 0){
            _CoinPool.withdrawProfit();
            require(uint256(dayProfit.totalProfit) <= address(this).balance, "DoProfitStart balance check");
        }
        dayProfit.totalTBT = totalTBT;
        dayProfit.blockInfo == block.number;
        dayProfit.sharePercentage = sharePercentage;
    }

    function DoShareProfit() public gameOpened {
        require(isShareExecing == true, "DoSnapsoot isShareExecing");
        DayProfit storage dayProfit = profitHistory[shareTimestamp];
        if(dayProfit.totalProfit <= 0){
            isShareExecing = false;
        }

        uint256 end = nextShare + 100;
        if (end > holdersList.length)
            end = holdersList.length;
        uint256 i;
        for( i = nextShare; i < end; i++) {
            address holder = holdersList[i];
            dayProfit.holders[holder] = holderTBTAmount[holder];
            holder.transfer(uint256(dayProfit.totalProfit) * dayProfit.holders[holder] * 100 / dayProfit.totalTBT / dayProfit.sharePercentage);
        }
        nextShare = i;
        if (nextShare >= holdersList.length) {
            owner.transfer(address(this).balance);
            isShareExecing = false;
        }
    }
}