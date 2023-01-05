// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "./interface/IERC20.sol";
import "./library/SafeTransfer.sol";


contract BuddyDao is Ownable, Pausable, ReentrancyGuard, SafeTransfer, AutomationCompatibleInterface {

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    uint256 public TimeInterval;
    // Initial time per timing
    uint256 public StartTimeInterval;

    // Monthly fee rate
    uint256 public ServiceFee;
    address public ServiceFeeAddress;
    // Annual Rate
    uint256 public MaxFixedRate;
    uint256 constant baseDecimal = 1e18;
    uint256 constant baseYear = 365 days;

    // lend info
    struct Lender {
        // approve address
        address Address;
        string Alias;
        address Token;
        uint256 FixedRate;
        uint256 CreditLine;
        uint256 Amount;
        // Whether to completely deauthorize
        bool isCancel;
    }

    // borrower info
    struct Borrower {
        address Creditors;
        string Alias;
        address Token;
        uint256 FixedRate;
        uint256 CreditLine;
        uint256 Amount;
        // Calculation of fee start time
        uint256 BorrowStartTime;
        // Whether to completely deauthorize
        bool isCancel;
    }


    // total borrower info
    address[] public totalBorrower;
    mapping(address => bool) public isTotalBorrower;

    // Lender homepage data
    mapping(address => Lender[]) public LenderData;
    // Borrower homepage data
    mapping(address => Borrower[])  public BorrowerData;

    // lend info index
    mapping (address => mapping(address => uint256)) LenderIndex;
    // borrower info index
    mapping (address => mapping(address => uint256)) BorrowerIndex;

    // log
    event SetServiceFee(uint256 _old, uint256 _new);
    event SetServiceFeeAddress(address _oldAddress, address _newAddress);
    event SetMaxFixedRate(uint256 _oldFixedRate, uint256 _newFixedRate);
    event Trust(address indexed _address, string _alias, address _token, uint256 indexed  _fixedRate, uint256 indexed _amount);
    event ReduceTrust(address _approveAddress, uint256 _lendIndex,uint256 _borrowerIndex, uint256 _cancelAmount);
    event WithdrawAssets(address _lendAddress, uint256 _lendIndex,uint256 _borrowerIndex, uint256 _borrowerAmount);
    event Payment(address _lendAddress, uint256 _lendIndex,uint256 _borrowerIndex, uint256 _payAmount);


    constructor (uint256 _serviceFee, address _serviceFeeAddress, uint256 _maxFixedRate) {
        require(_serviceFee != 0, "serviceFee must be a positive number");
        require(_serviceFeeAddress != address(0), "serviceFeeAddress is not a zero address");
        ServiceFee = _serviceFee;
        ServiceFeeAddress = _serviceFeeAddress;
        MaxFixedRate = _maxFixedRate;
        StartTimeInterval = block.timestamp;
    }


    function setTimeInterval(uint256 _newTimeInterval)external onlyOwner {
        require(_newTimeInterval > 0, "New Time Interval must be great 0");
        TimeInterval = _newTimeInterval;
    }


    function setServiceFee(uint256 _serviceFee) external onlyOwner {
        require(_serviceFee !=0, "serviceFee must be a positive number");
        emit SetServiceFee(ServiceFee, _serviceFee);
        ServiceFee = _serviceFee;
    }

    function setServiceFeeAddress(address _newAddress) external onlyOwner {
        require(_newAddress != address(0), "serviceFeeAddress is not a zero address");
        emit SetServiceFeeAddress(ServiceFeeAddress, _newAddress);
        ServiceFeeAddress = _newAddress;
    }

    function setMaxFixedRate(uint256 _maxFixedRate) external onlyOwner {
        require(_maxFixedRate >= 0, "maxFixedRate must be greater than or equal to 0");
        emit SetMaxFixedRate(MaxFixedRate, _maxFixedRate);
        MaxFixedRate = _maxFixedRate;
    }


    // Get Lender Info
    function GetLenderAddressLengeth(address _lenderAddress) public view returns(uint256) {
        uint256 lenLender = (LenderData[_lenderAddress]).length;
        return lenLender;
    }

    // Get Lends Homepage Data
    function GetLenderData(address _lenderAddress) public view returns (Lender[] memory ) {
        Lender[] memory lenderAddressData = LenderData[_lenderAddress];
        return lenderAddressData;
    }
    // Get Lender Index Info
    function GetLenderIndexData(address _lenderAddress, uint256 _index) public view returns (Lender memory) {
        Lender memory lenderAddressData = LenderData[_lenderAddress][_index];
        return lenderAddressData;
    }

    // Get lend index
    function GetLendIndex(address _lendAddress, address _approveAddress) public view returns(uint256 index){
        return LenderIndex[_lendAddress][_approveAddress];
    }

    // Get Borrower index
    function GetBorrowerIndex(address _borrowerAddress, address _Creditors) public view returns(uint256 index){
        return BorrowerIndex[_borrowerAddress][_Creditors];
    }


    // Get Borrower Info
    function GetBorrowerAddressLengeth(address _borrowerAddress) public view returns(uint256) {
        uint256 lenBorrower = (BorrowerData[_borrowerAddress]).length;
        return lenBorrower;
    }

    // Get Borrower Homepage Data
    function GetBorrowerData(address _borrowerAddress) public view returns (Borrower[] memory) {
        Borrower[] memory borrowerAddressData = BorrowerData[_borrowerAddress];
        return borrowerAddressData;
    }

    // Get Borrower Index Info
    function GetBorrowerIndexData(address _borrowerAddress, uint256 _index) public view returns (Borrower memory) {
        Borrower memory borrowerAddressData = BorrowerData[_borrowerAddress][_index];
        return borrowerAddressData;
    }


    function NewTrust(address _approveAddress, string memory _alias, address _token, uint256 _fixedRate, uint256 _amount) external nonReentrant whenNotPaused {
        require(_approveAddress != address(0), "_approveAddress is not a zero address");
        require(_token != address(0), "_token is not a zero address");
        require(_fixedRate <= MaxFixedRate, "Must be less than the maximum interest");

        uint256 allowBalance = IERC20(_token).allowance(msg.sender, address(this));
        require(_amount <= allowBalance, "Lack of authorized");

        uint256 erc20Balance = IERC20(_token).balanceOf(msg.sender);
        require(_amount <= erc20Balance, "The authorized quantity must be greater than the balance");

        // save lend info
        Lender[] storage lendInfo = LenderData[msg.sender];
        lendInfo.push(Lender({
            Address: _approveAddress,
            Alias: _alias,
            Token: _token,
            FixedRate: _fixedRate,
            CreditLine: _amount,
            Amount:0,
            isCancel: false
        }));
        uint256 lendInfoLength = lendInfo.length;
        LenderIndex[msg.sender][_approveAddress] = lendInfoLength - 1;

        // save borrower info
        Borrower[]  storage borrowerInfo = BorrowerData[_approveAddress];
        borrowerInfo.push(Borrower({
            Creditors: msg.sender,
            Alias: "",
            Token: _token,
            FixedRate: _fixedRate,
            CreditLine: _amount,
            Amount: 0,
            BorrowStartTime:0,
            isCancel: false
        }));
        uint256 borrowerInfoLength = borrowerInfo.length;
        BorrowerIndex[_approveAddress][msg.sender] = borrowerInfoLength - 1;
        // log
        emit Trust(_approveAddress, _alias, _token, _fixedRate, _amount);
    }


    function RemoveTrust(address _approveAddress, uint256 _lendIndex, uint256 _borrowerIndex, uint256 _cancelAmount) external nonReentrant whenNotPaused {
        require(_approveAddress != address(0), "approveAddress is not a zero address");
        require(_cancelAmount != 0, "The number of cancellations cannot be equal to 0");
        require(_approveAddress != msg.sender, "approveAddress is not msg.sender");

        Lender[]  storage lendInfo = LenderData[msg.sender];
        uint256 lendInfoLength = lendInfo.length;
        require(_lendIndex <= lendInfoLength - 1, "Index Overrun");
        Lender storage personalLenderInfo = LenderData[msg.sender][_lendIndex];


        Borrower[] storage borrowerInfo = BorrowerData[_approveAddress];
        uint256 borrowInfoLength = borrowerInfo.length;
        require(_borrowerIndex <= borrowInfoLength - 1, "borrower index Overrun");
        Borrower storage personalBorrowerInfo = BorrowerData[_approveAddress][_borrowerIndex];

        require(!personalLenderInfo.isCancel, "The authorization id record has been cancelled");
        // Number of Cancellations <= Number of Trusts - Number of Lending
        require(_cancelAmount <= personalLenderInfo.CreditLine - personalBorrowerInfo.Amount , "The number of cancellations cannot be greater than the number of authorizations");

        if (_cancelAmount == personalLenderInfo.CreditLine) {
            // Complete cancellation
            personalLenderInfo.isCancel = true;
            personalBorrowerInfo.isCancel = true;
            personalLenderInfo.CreditLine = personalLenderInfo.CreditLine - _cancelAmount;
            personalBorrowerInfo.CreditLine = personalBorrowerInfo.CreditLine - _cancelAmount;
        } else {
            // Partial cancellation of authorization
            personalLenderInfo.CreditLine = personalLenderInfo.CreditLine - _cancelAmount;
            personalBorrowerInfo.CreditLine = personalBorrowerInfo.CreditLine - _cancelAmount;
        }
        // log
        emit ReduceTrust(_approveAddress, _lendIndex, _borrowerIndex, _cancelAmount);
    }


    function Withdrawal(address _lendAddress, uint256 _lendIndex, uint256 _borrowerIndex, uint256 _borrowerAmount) external nonReentrant whenNotPaused {

        require(_lendAddress != address(0), "_lendAddress is not a zero address");
        require(_lendAddress != msg.sender, "lendAddress is not msg.sender");
        require(_borrowerAmount != 0, "The number of borrower amount cannot be equal to 0");

        Borrower[] storage borrowerInfo = BorrowerData[msg.sender];
        uint256 borrowerInfoLength = borrowerInfo.length;
        require(_borrowerIndex <= borrowerInfoLength - 1, "Index Overrun");
        Borrower storage personalBorrowerInfo = BorrowerData[msg.sender][_borrowerIndex];

        require(!personalBorrowerInfo.isCancel, "The authorization id record has been cancelled");

        // Current number of remaining loans = number of credits - number already lent
        require(_borrowerAmount <= personalBorrowerInfo.CreditLine - personalBorrowerInfo.Amount, "The number of withdrawals must be less than or equal to the effective number");
        // Determine if lend's current balance is available for borrowing
        uint256 lenderBalance = IERC20(personalBorrowerInfo.Token).balanceOf(personalBorrowerInfo.Creditors);
        require(_borrowerAmount <= lenderBalance, "The lend balance is less than the borrowable quantity");

        // save borrower info
        personalBorrowerInfo.Amount = personalBorrowerInfo.Amount + _borrowerAmount;
        //Add time stamp to start borrowing money and calculate interest
        if (personalBorrowerInfo.BorrowStartTime == 0) {
            personalBorrowerInfo.BorrowStartTime = block.timestamp;
        }

        // save data
        Lender[]  storage lendInfo = LenderData[_lendAddress];
        uint256 lendInfoLength = lendInfo.length;
        require(_lendIndex <= lendInfoLength - 1, "Index Overrun");

        Lender storage personalLenderInfo = LenderData[_lendAddress][_lendIndex];
        personalLenderInfo.Amount = personalLenderInfo.Amount + _borrowerAmount;

        // Total number of borrowers, statistics of fees charged by the platform
        bool result = isTotalBorrower[msg.sender];
        if (!result) {
            totalBorrower.push(msg.sender);
            isTotalBorrower[msg.sender] = true;
        }
        // borrow token
        uint256 amount = getPayableAmount(personalBorrowerInfo.Token, personalBorrowerInfo.Creditors, msg.sender, _borrowerAmount);
        require(amount == _borrowerAmount, "The actual money lent is not the same as the money needed to be borrowed");
        // log
        emit WithdrawAssets(_lendAddress, _lendIndex, _borrowerIndex, _borrowerAmount);
    }


    function Pay(address _lendAddress, uint256 _lendIndex, uint256 _borrowerIndex, uint256 _payAmount) external nonReentrant whenNotPaused {
        require(_lendAddress != address(0), "_lendAddress is not a zero address");
        require(_lendAddress != msg.sender, "lendAddress is not msg.sender");
        require(_payAmount != 0, "The number of payment amount cannot be equal to 0");

        Borrower[] storage borrowerInfo = BorrowerData[msg.sender];
        uint256 borrowerInfoLength = borrowerInfo.length;
        require(_borrowerIndex <= borrowerInfoLength - 1, "Index Overrun");

        // Compare the number of returns
        Borrower storage personalBorrowerInfo = BorrowerData[msg.sender][_borrowerIndex];

         // Interest calculation
        uint256 borrowerInterest = calculatingInterest(_lendAddress, msg.sender,  _borrowerIndex,  _payAmount);

        require(_payAmount <= personalBorrowerInfo.Amount + borrowerInterest, "The returned quantity must be less than or equal to the borrowed quantity.");

        // Calculate whether the user's balance is sufficient for return
        uint256 userBalance = IERC20(personalBorrowerInfo.Token).balanceOf(msg.sender);
        require(userBalance >= _payAmount + borrowerInterest, "Insufficient balance");
        // Actual quantity returned = Quantity + Interest
        uint256 actualPay = _payAmount + borrowerInterest;
        // Payment
        uint256 amount = getPayableAmount(personalBorrowerInfo.Token, msg.sender, personalBorrowerInfo.Creditors, actualPay);
        require(amount == actualPay, "The actual amount and the deducted amount do not match");

        // save borrower info
        personalBorrowerInfo.Amount = personalBorrowerInfo.Amount - _payAmount;
        if (personalBorrowerInfo.Amount == 0) {
            personalBorrowerInfo.BorrowStartTime = 0;
        }
        // save  lend info
        Lender[]  storage lendInfo = LenderData[_lendAddress];
        uint256 lendInfoLength = lendInfo.length;
        require(_lendIndex <= lendInfoLength - 1, "Index Overrun");

        Lender storage personalLenderInfo = LenderData[_lendAddress][_lendIndex];
        personalLenderInfo.Amount = personalLenderInfo.Amount - _payAmount;
        // log
        emit Payment(_lendAddress, _lendIndex, _borrowerIndex, _payAmount);
    }


    function calculatingInterest(address _lendAddress, address _borrower, uint256 _index, uint256 _payAmount) public view returns(uint256){
        require(_lendAddress != address(0), "_lendAddress is not a zero address");
        require(_payAmount != 0, "The number of payment amount cannot be equal to 0");
        Borrower[] storage borrowerInfo = BorrowerData[_borrower];
        uint256 borrowerInfoLength = borrowerInfo.length;
        require(_index <= borrowerInfoLength - 1, "Index Overrun");
        Borrower storage personalBorrowerInfo = BorrowerData[_borrower][_index];
        uint256 timeRatio = (block.timestamp.sub(personalBorrowerInfo.BorrowStartTime)).mul(baseDecimal).div(baseYear);
        uint256 interest = (timeRatio.mul((personalBorrowerInfo.FixedRate).mul(personalBorrowerInfo.Amount))).div(baseDecimal).div(baseDecimal);
        return interest;
    }

    // chainlink auto
    function checkUpkeep(bytes calldata) external view override whenNotPaused returns (bool upkeepNeeded, bytes memory){
        // Current time is greater than the time period
        if (block.timestamp > StartTimeInterval + TimeInterval) {
            upkeepNeeded = totalBorrower.length > 0;
        }
    }


    // chainlink logic
    function performUpkeep(bytes calldata) external override  {

        if (block.timestamp > StartTimeInterval + TimeInterval) {
            if (totalBorrower.length > 0) {
                for (uint256 i = 0; i < totalBorrower.length; i++){
                      // Find borrower information
                      Borrower[] memory data = BorrowerData[totalBorrower[i]];
                      if (data.length == 0) {
                          continue;
                      }
                      for (uint256 index = 0; index < data.length; index++){
                          if (data[index].isCancel){
                              continue;
                          }
                          if (data[index].Amount > 0 ){
                              // Calculate fixed interest = Current number of borrowings * Fixed interest
                              uint256 fixedRate = (data[index].Amount.mul(ServiceFee)).div(baseDecimal);
                              // Determine whether the lending user has sufficient balance to pay the fee
                              uint256 borrowerBalance = IERC20(data[index].Token).balanceOf(totalBorrower[i]);
                              if (borrowerBalance < fixedRate ){
                                  continue;
                              }
                              // payment fee
                              uint256 amount = getPayableAmount(data[index].Token, totalBorrower[i], ServiceFeeAddress, fixedRate);
                              require(amount == fixedRate, "The actual amount and the deducted amount do not match");
                          }
                      }
                  }
            }
            // Update the starting point of the current time period
            StartTimeInterval = block.timestamp;
        }
    }

}






















