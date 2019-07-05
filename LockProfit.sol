pragma solidity >=0.4.0;

import "game.sol";

contract LockProfit{

    uint256 public period;
    address public owner;
    CoinPool public  _CoinPool;
    uint256 public activedTime;
    LockProfit public preProfit;

    modifier onlyOwner(){require(msg.sender==owner, "onlyOwner");_;}
    modifier gameOpened(){require(opening, "onlyOpened");_;}
    modifier onlyCoinPool(){require(msg.sender==address(_CoinPool), "onlyCoinPool");_;}
    modifier onlyActived(){require(activedTime > 0, "onlyActived");_;}

    TRC20 public tbt;
    struct Order{
        uint256 amount;
        uint256 time;
    }
    struct UnlockOrderList{
        uint256 preLength;
        Order[] orders;
    }
    struct LockOrderList{
        uint256 preLength;
        Order[] orders;
    }
    struct WithdrawOrderList{
        uint256 preLength;
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
    mapping(address=>LockOrderList) public lockTBTHistory;
    mapping(address=>UnlockOrderList) public unlockTBTHistory;
    mapping(address=>WithdrawOrderList) public withdrawTBTHistory;

    mapping(address=>uint256) public holderTBTAmount;
    uint256 public totalTBT;
    address[] public holdersList;
    bool public isShareExecing;
    uint256 public nextShare;
    uint256 public shareTimestamp;
    uint256 public sharePercentage;
    bool public opening;

    uint256 public copyIndex;

    function () external payable{
        require(msg.data.length == 0, "transfer only");
    }
    constructor(CoinPool pool, uint256 _percentage) public{
        _CoinPool = pool;
        period = 1 days;
        updateUnsafe();
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
    function getLockOrderLengthByAddress(address holder) public view returns(uint256){
        return lockTBTHistory[holder].preLength + lockTBTHistory[holder].orders.length;
    }

    function getUnlockOrderLengthByAddress(address holder) public view returns(uint256){
        return unlockTBTHistory[holder].preLength + unlockTBTHistory[holder].orders.length;
    }

    function getWidthdrawLengthByAddress(address holder) public view returns(uint256){
        return withdrawTBTHistory[holder].preLength + withdrawTBTHistory[holder].nextDeal;
    }

    function getWithdrawAmountByAddress(address holder) public view returns(uint256){
        Order[] storage unlockOrders = unlockTBTHistory[holder].orders;
        WithdrawOrderList storage withdraw = withdrawTBTHistory[holder];
        uint256 i;
        uint256 amount = 0;
        for(i = withdraw.nextDeal; i < unlockOrders.length; i++){
            Order storage order = unlockOrders[i];
            if(order.time + 1 days >= block.timestamp)
                break;
            amount += order.amount;
        }
        return amount;
    }

    function getUnlockAmountByAddress(address holder) public view returns(uint256){
        if (withdrawTBTHistory[holder].nextDeal == unlockTBTHistory[holder].orders.length)
            return 0;
        uint256 amount = 0;
        for(uint256 i = withdrawTBTHistory[holder].nextDeal; i < unlockTBTHistory[holder].orders.length; i++){
            amount += unlockTBTHistory[holder].orders[i].amount;
        }
        return amount;
    }
    function getMyUnlockAmount() public view returns(uint256){
        return getUnlockAmountByAddress(msg.sender);
    }
    function getUnlockAmountByIndex(uint256 holderIndex) public view returns(address, uint256){
        address holder = holdersList[holderIndex];
        return (holder,getUnlockAmountByAddress(holder));
    }
    function getHolderAmount() public view returns(uint256){
        return holdersList.length;
    }
    // return (holder, holderLength, totalTBT, curProfits,  holder.lockTBT, isSharing), 
    function getHolderInfo(address holder) public view returns (address, uint256, uint256, int256, uint256, uint256, uint256, bool){
        return (holder, holdersList.length, totalTBT, _CoinPool.getProfits(), holderTBTAmount[holder], getUnlockAmountByAddress(holder), getWithdrawAmountByAddress(holder), isShareExecing);
    }

    function getMyInfo() public view returns (address, uint256, uint256, int256, uint256, uint256, uint256, bool){
        return getHolderInfo(msg.sender);
    }

    function getInfoByIndex(uint256 holderIndex) public view returns (address, uint256, uint256, int256, uint256, uint256, uint256, bool){
        address holder = holdersList[holderIndex];
        return getHolderInfo(holder);
    }

/* ------- order info ------ */
    function getOrderInfoByAddress(address holder) public view returns(address, uint256, uint256, uint256) {
        return (holder, getLockOrderLengthByAddress(holder), getUnlockOrderLengthByAddress(holder), getWidthdrawLengthByAddress(holder));
    }

    function getMyOrderInfo() public view returns(address, uint256, uint256, uint256){
        return getOrderInfoByAddress(msg.sender);
    }

    function getOrderInfoByIndex(uint256 holderIndex) public view returns(address, uint256, uint256, uint256){
        address holder = holdersList[holderIndex];
        return getOrderInfoByAddress(holder);
    }

/* ------- order detail ---------*/
    function getHistoryOrder(address holder, uint256 orderIndex, uint256 isLockOrder) public view returns(uint256, uint256){
        if(orderIndex < unlockTBTHistory[holder].preLength)
            return preProfit.getHistoryOrder(holder, orderIndex, isLockOrder);
        Order[] storage orders = unlockTBTHistory[holder].orders;
        if(isLockOrder == 1)
            orders = lockTBTHistory[holder].orders;
        return (orders[orderIndex].amount, orders[orderIndex].time);
    }

    function getMyHistoryOrder(uint256 orderIndex, uint256 isLockOrder) public view returns(uint256, uint256){
        return getHistoryOrder(msg.sender, orderIndex, isLockOrder);
    }

    function getHistoryOrderByIndex(uint256 holderIndex, uint256 orderIndex, uint256 isLockOrder) public view returns(uint256, uint256){
        address holder = holdersList[holderIndex];
        return getHistoryOrder(holder, orderIndex, isLockOrder);
    }

/* ------- profit info ------ */

    function queryHistoryProfitByTime(address holder, uint256 time) public view returns(int256, uint256, uint256, uint256, uint256){
        if(time < activedTime)
            return preProfit.queryHistoryProfitByTime(holder, time);
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

    function changePeriod(uint256 _period) external onlyOwner{
        period = _period;
    }

    function updateCoinPool() external onlyCoinPool{
        _CoinPool = _CoinPool.nextCoinPool();
        update();
    }

    function updateUnsafe() internal {
        owner = _CoinPool.owner();
        tbt = _CoinPool.tbt();
        opening = _CoinPool.isOpen();
        tbt.approve(owner, tbt.totalSupply());
    }

    function update() public onlyActived {
        updateUnsafe();
    }

    function switchCoinPool(address pool) external onlyOwner{
        _CoinPool = CoinPool(pool);
        update();
    }
/* ------ update -------*/

function transferToNewProfit(LockProfit newAddr)  external onlyCoinPool onlyActived {
    tbt.approve(address(newAddr), tbt.totalSupply());
    update();
}

function copyAndActive(uint256 n) public {
    require(activedTime == 0, "already actived");
    require(n <= 100, "copy to much");
    require(preProfit.opening()==false, "preProfit must close");
    require(totalTBT == preProfit.totalTBT(), "preProfit must not changed");
    uint256 total = preProfit.getHolderAmount();
    uint256 end = copyIndex + n;
    if (end > total)
        end = total;
    for(uint256 i = copyIndex; i < end; i++){
        address holder = preProfit.holdersList(i);
        holdersList.push(holder);
        lockTBTHistory[holder].preLength = preProfit.getLockOrderLengthByAddress(holder);
        unlockTBTHistory[holder].preLength = preProfit.getUnlockOrderLengthByAddress(holder);
        withdrawTBTHistory[holder].preLength = preProfit.getWidthdrawLengthByAddress(holder);
    }
    if(end == total){
        tbt.transferFrom(address(preProfit), address(this), tbt.balanceOf(address(preProfit)));
        activedTime = block.timestamp;
        update();
    }
}

function copyData(LockProfit preAddr) external onlyCoinPool {
    require(activedTime == 0, "already actived");
    preProfit = preAddr;
    totalTBT = preProfit.totalTBT();
    sharePercentage = preProfit.sharePercentage();
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
        require(n <= 100, "withdrawTBT to much");
        WithdrawOrderList storage withdraw = withdrawTBTHistory[msg.sender];
        uint256 start = getWidthdrawLengthByAddress(msg.sender);
        uint256 end = getUnlockOrderLengthByAddress(msg.sender);
        if(end > start + n)
            end = start + n;
        for(uint256 i = start; i < end; i++){
            (uint256 amount, uint256 time) = getHistoryOrder(msg.sender, i, 0);
            if(time + period + 4 seconds >= block.timestamp)
                break;
            tbt.transfer(msg.sender, amount);
            withdraw.nextDeal++;
        }
    }

    function withdrawAllTRX() public onlyOwner{
        msg.sender.transfer(address(this).balance);
    }

    function DoShareProfitStart() public gameOpened {
        require(shareTimestamp + period < timeAlign(), "DoProfitStart replay check");
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
        dayProfit.blockInfo = block.number;
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