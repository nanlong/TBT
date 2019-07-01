pragma solidity >=0.4.0;

import "game.sol";

contract LockProfit is Game{
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
        mapping(address=>uint256) holders;
    }

    mapping(uint256=>DayProfit) public profitHistory;
    mapping(address=>LockOrderList) lockTBTHistory;
    mapping(address=>UnlockOrderList) unlockTBTHistory;
    mapping(address=>WithdrawOrderList) public withdrawTBTHistory;

    mapping(address=>uint256) public playerTBTAmount;
    uint256 public totalTBT;
    address[] public holdersList;
    bool public isShareExecing;
    uint256 public nextShare;
    uint256 public shareTimestamp;
    uint256 public sharePercentage;

    constructor(string _name, address pool, uint256 _percentage) Game(_name,pool) public{
        tbt = _CoinPool.tbt();
        isShareExecing = false;
        changeSharePercentage(_percentage);
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
        return (holder, holdersList.length, totalTBT, _CoinPool.getProfits(), playerTBTAmount[holder], isShareExecing);
    }

    function getMyInfo() public view returns (address, uint256, uint256, int256, uint256, bool){
        return getHolderInfo(msg.sender);
    }

    function getInfoByIndex(uint256 index) public view returns (address, uint256, uint256, int256, uint256, bool){
        address holder = holdersList[index];
        return getHolderInfo(holder);
    }

/* ------- order info ------ */
    function getOrderInfoByAddress(address holder) public view returns(address, uint256, uint256, uint256) {
        return (holder, lockTBTHistory[holder].orders.length, unlockTBTHistory[holder].orders.length, withdrawTBTHistory[holder].nextDeal);
    }

    function getMyOrderInfo() public view returns(address, uint256, uint256, uint256){
        return getOrderInfoByAddress(msg.sender);
    }

    function getOrderInfoByIndex(uint256 index) public view returns(address, uint256, uint256, uint256){
        address holder = holdersList[index];
        return getOrderInfoByAddress(holder);
    }

/* ------- profit info ------ */

    function queryHistoryProfitByTime(address holder, uint256 time) public view returns(int256, uint256, uint256, uint256){
        DayProfit storage dayProfit = profitHistory[timeKey(time)];
        return (dayProfit.totalProfit, dayProfit.totalTBT, dayProfit.blockInfo, dayProfit.holders[holder]);
    }

    function queryMyHistoryProfitByTime(uint256 time) public view returns(int256, uint256, uint256, uint256){
        return queryHistoryProfitByTime(msg.sender, time);
    }

    function queryHistoryLockInfoByIndex(uint256 index, uint256 time) public view returns(int256, uint256, uint256, uint256){
        address holder = holdersList[index];
        return queryHistoryProfitByTime(holder, time);
    }
/* ------ only owner -----*/
    function changeSharePercentage(uint256 _percentage) public onlyOwner{
        require(_percentage <= 100, "_percentage check");
        sharePercentage = _percentage;
    }
/* ------ rw logic ------ */

    function appendOrder(Order[] storage orders, uint256 tbtAmount) internal {
        orders.length++;
        Order storage order = orders[orders.length-1];
        order.time = block.timestamp;
        order.amount = tbtAmount;
    }

    function lockTBT(uint256 tbtAmount) public{
        require(isShareExecing == false, "lockTBT share check");
        tbt.transferFrom(msg.sender, address(this), tbtAmount);
        Order[] storage orders = lockTBTHistory[msg.sender].orders;
        if (orders.length == 0)
            holdersList.push(msg.sender);
        appendOrder(orders, tbtAmount);
        totalTBT += tbtAmount;
        playerTBTAmount[msg.sender] += tbtAmount;
    }

    function unlockTBT(uint256 tbtAmount) public {
        require(isShareExecing == false, "unlockTBT share check");
        require(playerTBTAmount[msg.sender] >= tbtAmount, "unlockTBT check");
        Order[] storage orders = unlockTBTHistory[msg.sender].orders;
        appendOrder(orders, tbtAmount);
        totalTBT -= tbtAmount;
        playerTBTAmount[msg.sender] -= tbtAmount;
    }

    function withdrawLimitedTBT(uint256 n) public {
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

    function DoShareProfitStart() public {
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
            require(uint256(dayProfit.totalProfit) == address(this).balance, "DoProfitStart balance check");
        }
        dayProfit.totalTBT = totalTBT;
        dayProfit.blockInfo == block.number;
    }

    function DoShareProfit() public {
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
            dayProfit.holders[holder] = playerTBTAmount[holder];
            holder.transfer(uint256(dayProfit.totalProfit) * dayProfit.holders[holder] * 100 / dayProfit.totalTBT / sharePercentage);
        }
        nextShare = i;
        if (nextShare >= holdersList.length) {
            owner.transfer(address(this).balance);
            isShareExecing = false;
        }
    }
}