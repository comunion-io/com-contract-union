// SPDX-License-Identifier: SimPL-2.0
pragma solidity >=0.8.x <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

struct Parameters {
    address depositToken;
    bool depositTokenIsNative;
    uint256 founderDepositAmount;
    uint256 applicantDepositMinAmount;
    uint256 applyDeadline;
}

contract BountyFactory is Ownable {
    address[] private arrChildren;
    mapping(address => bool) private mapChildren;

    event Created(address founder, address bounty, Parameters paras);

    function createBounty(address _depositToken, uint256 _founderDepositAmount, uint256 _applicantDepositAmount, uint256 _applyDeadline) public {
        require(_applyDeadline > block.timestamp, "Applicant cutoff date is expired");
        // address _stableToken = address(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E);   //Avalanche Mainnet
        // address _stableToken = address(0x8f81b9B08232F8E8981dAa87854575d7325A9439);   //Avalanche Testnet
        Parameters memory paras = Parameters({depositToken: _depositToken,
        depositTokenIsNative: false,
        founderDepositAmount: _founderDepositAmount,
        applicantDepositMinAmount: _applicantDepositAmount,
        applyDeadline: _applyDeadline});
        Bounty bounty = new Bounty(address(this), msg.sender, paras);
        if (paras.founderDepositAmount > 0) {
            IERC20 depositToken = IERC20(_depositToken);
            require(depositToken.balanceOf(msg.sender) >= _founderDepositAmount, "Deposit token balance is insufficient");
            require(depositToken.allowance(msg.sender, address(this)) >= _founderDepositAmount, "Deposit token allowance is insufficient");
            require(depositToken.transferFrom(msg.sender, address(bounty), _founderDepositAmount), "Deposit token transferFrom failure");
        }

        arrChildren.push(address(bounty));
        mapChildren[address(bounty)] = true;
        emit Created(msg.sender, address(bounty), paras);
    }

    function children() external view returns (address[] memory) {
        return arrChildren;
    }

    function isChild(address _address) external view returns (bool) {
        return mapChildren[_address];
    }
}

contract Bounty is Ownable {
    using SafeMath for uint;

    enum BountyStatus {
        Pending, ReadyToWork, WorkStarted, Completed, Expired
    }
    enum ApplicantStatus {
        Pending, Applied, Refunded, Withdraw, Refused, Approved, Unapproved
    }
    enum Role {
        Pending, Founder, Applicant, Others
    }

    struct Applicant {
        uint256 depositAmount;
        ApplicantStatus status;
    }

    IERC20 private depositToken;
    address private factory;
    address private founder;
    address payable private thisAccount;
    Parameters private paras;
    uint256 private founderDepositAmount;
    uint256 private applicantDepositAmount;
    uint256 private timeLock;
    bool private depositLock;
    bool internal locked;
    BountyStatus private bountyStatus;
    address[] arrayApplicants;
    mapping(address => Applicant) mappedApplicants;
    mapping(address => bool) mappedDepositLockers;
    mapping(address => bool) mappedDepositUnlockers;

    event Created(address owner, address factory, address founder, Parameters paras);
    event Deposit(address from, uint256 amount);
    event Refund(address to, uint256 amount);

    modifier onlyFounder() {
        _checkFounder();
        _;
    }

    modifier onlyOthers() {
        _checkOthers();
        _;
    }

    modifier onlyApplied() {
        _checkAppliedApplicant();
        _;
    }

    modifier inApplyTime() {
        _checkInApplyTime();
        _;
    }

    modifier inReadyToWork() {
        _checkBountyStatus(BountyStatus.ReadyToWork, "Bounty status not in ready to work");
        _;
    }

    modifier inWorkStarted() {
        _checkBountyStatus(BountyStatus.WorkStarted, "Bounty status not in work started");
        _;
    }

    modifier notCompleted() {
        _checkNotBountyStatus(BountyStatus.Completed, "Bounty status is completed");
        _;
    }

    modifier notExpired() {
        _checkNotBountyStatus(BountyStatus.Expired, "Bounty status is expired");
        _;
    }

    modifier depositLocked() {
        require(depositLock, "Deposit is unlock");
        _;
    }

    modifier depositUnlock() {
        require(!depositLock, "Deposit is locked");
        _;
    }

    modifier zeroDeposit() {
        require((founderDepositAmount+applicantDepositAmount) == 0, "Deposit balance more than zero");
        _;
    }

    modifier nonzeroDeposit() {
        require((founderDepositAmount+applicantDepositAmount) > 0, "Deposit amount is zero");
        _;
    }

    modifier depositLocker() {
        _checkDepositLocker(msg.sender);
        _;
    }

    modifier depositUnlocker() {
        _checkDepositUnlocker(msg.sender);
        _;
    }

    modifier noReentrant() {
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }

    constructor(address _factory, address _founder, Parameters memory _paras) {
        factory = _factory;
        founder = _founder;
        paras = _paras;
        bountyStatus = _statusFromTime();
        founderDepositAmount = paras.founderDepositAmount;
        depositLock = false;
        timeLock = 0;
        if (paras.depositToken == address(0)) {
            paras.depositTokenIsNative = true;
        } else {
            paras.depositTokenIsNative = false;
            depositToken = IERC20(paras.depositToken);
        }
        thisAccount = payable(address(this));
        transferOwnership(_founder);

        emit Created(owner(), factory, founder, paras);
    }

    function deposit(uint256 _amount) public payable onlyFounder inReadyToWork {
        require(_amount > 0, "Deposit amount is zero");
        _deposit(_amount);
        founderDepositAmount = founderDepositAmount.add(_amount);
    }

    function release() public payable onlyFounder depositUnlock nonzeroDeposit {
        _releaseAllDeposit();
    }

    function close() public payable onlyFounder zeroDeposit notCompleted notExpired {
        require(_refundDepositToken(payable(founder), _getBalance(thisAccount)), "Transfer balance to the founder failure");
        bountyStatus = BountyStatus.Completed;
    }

    function approveApplicant(address _address) public onlyFounder inReadyToWork {
        (,,bool _isAppliedApplicant,) = _applicantState(_address);
        require(_isAppliedApplicant || (!_isAppliedApplicant && paras.applicantDepositMinAmount == 0),
            "To be approved must a applicant");

        _refuseOtherApplicants(_address);
        _addApplicant(_address, 0, ApplicantStatus.Approved);
        bountyStatus = BountyStatus.WorkStarted;
        depositLock = true;
        mappedDepositLockers[_address] = true;
        mappedDepositUnlockers[_address] = true;
        _startTimer();
    }

    function unapproveApplicant(address _address) public onlyFounder inWorkStarted {
        (,bool _isApprovedApplicant,,) = _applicantState(_address);
        require(_isApprovedApplicant, "Applicant status is not approved");
        mappedApplicants[_address].status = ApplicantStatus.Unapproved;
        mappedDepositLockers[_address] = false;
    }

    function applyFor(uint256 _amount) public payable onlyOthers inApplyTime inReadyToWork noReentrant {
        require(_amount >= paras.applicantDepositMinAmount, "Deposit amount less than limit");
        _deposit(_amount);
        _addApplicant(msg.sender, _amount, ApplicantStatus.Applied);
        applicantDepositAmount = applicantDepositAmount.add(_amount);
    }

    function releaseMyDeposit() public payable onlyApplied depositUnlock inReadyToWork noReentrant {
        _refundApplicant(msg.sender);
        mappedApplicants[msg.sender].status = ApplicantStatus.Withdraw;
    }

    function lock() public payable depositLocker depositUnlock {
        depositLock = true;
    }

    function unlock() public payable depositUnlocker depositLocked {
        depositLock = false;
    }

    function postUpdate() public depositLocker inWorkStarted {
        _startTimer();
    }

    function state() public view returns (uint8 _bountyStatus, uint _applicantCount, uint256 _depositBalance,
        uint256 _founderDepositAmount, uint256 _applicantDepositAmount,
        uint256 _applicantDepositMinAmount, bool _depositLock,
        uint256 _timeLock, uint8 _myRole,
        uint256 _myDepositAmount, uint8 _myStatus) {

        (uint8 _role, uint256 _depositAmount, uint8 _status) = whoAmI();

        return (uint8(bountyStatus), arrayApplicants.length, _getBalance(thisAccount), founderDepositAmount, applicantDepositAmount,
        paras.applicantDepositMinAmount, depositLock, timeLock, _role, _depositAmount, _status);
    }

    function whoAmI() public view returns (uint8 _role, uint256 _depositAmount, uint8 _applicantStatus) {
        return _whoIs(msg.sender);
    }

    function _depositIsLocked() internal view returns (bool) {
        if (timeLock == 0 || block.timestamp < timeLock) {
            return depositLock;
        } else {
            return false;
        }
    }

    function _deposit(uint256 _amount) internal {
        if (_amount > 0) {
            if (paras.depositTokenIsNative) {
                require(msg.value == _amount, "msg.value is not valid");
                require(msg.sender.balance >= _amount, "Your balance is insufficient");
                (bool isSend,) = thisAccount.call{value: _amount}("");
                require(isSend, "Transfer contract failure");
            } else {
                require(depositToken.allowance(msg.sender, thisAccount) >= _amount, "Your deposit token allowance is insufficient");
                require(depositToken.balanceOf(msg.sender) >= _amount, "Your deposit token balance is insufficient");
                require(depositToken.transferFrom(msg.sender, thisAccount, _amount), "Deposit token transferFrom failure");
            }
            emit Deposit(msg.sender, _amount);
        }
    }

    function _releaseAllDeposit() internal {
        _refundFounder();
        _refundApplicants();
    }

    function _refuseOtherApplicants(address _address) internal {
        for (uint i=0;i<arrayApplicants.length;i++) {
            if (address(arrayApplicants[i]) != address(_address)) {
                _refundApplicant(arrayApplicants[i]);
                mappedApplicants[arrayApplicants[i]].status = ApplicantStatus.Refused;
            }
        }
    }

    function _refundFounder() internal {
        require(_refundDepositToken(payable(founder), founderDepositAmount), "Refund deposit to the founder failure");
        founderDepositAmount = 0;
    }

    function _refundApplicants() internal {
        for (uint i=0;i<arrayApplicants.length;i++) {
            _refundApplicant(arrayApplicants[i]);
            if (mappedApplicants[arrayApplicants[i]].status == ApplicantStatus.Applied) {
                mappedApplicants[arrayApplicants[i]].status = ApplicantStatus.Refunded;
            }
        }
    }

    function _refundApplicant(address _address) internal {
        require(_refundDepositToken(payable(_address), mappedApplicants[_address].depositAmount), "Refund deposit to applicant failure");
        applicantDepositAmount = applicantDepositAmount.sub(mappedApplicants[_address].depositAmount);
        mappedApplicants[_address].depositAmount = 0;
    }

    function _refundDepositToken(address payable _to, uint256 _amount) internal returns (bool) {
        bool isSend = true;
        if (_amount > 0) {
            isSend = false;
            if (paras.depositTokenIsNative) {
                (isSend,) = _to.call{value: _amount}("");
                require(isSend, "Refund failure");
            } else {
                isSend = depositToken.transfer(_to, _amount);
                require(isSend, "Refund failure");
            }
            emit Refund(_to, _amount);
        }
        return isSend;
    }

    function _addApplicant(address _address, uint256 _amount, ApplicantStatus _status) internal {
        (bool _isApplicant,,) = _getApplicant(_address);
        if (!_isApplicant) {
            arrayApplicants.push(_address);
        }
        mappedApplicants[_address].status = _status;
        mappedApplicants[_address].depositAmount = mappedApplicants[_address].depositAmount.add(_amount);
    }

    function _getBalance(address _address) internal view returns (uint256) {
        if (paras.depositTokenIsNative) {
            return _address.balance;
        } else {
            return depositToken.balanceOf(_address);
        }
    }

    function _startTimer() internal {
        timeLock = block.timestamp + 5 days;
    }

    function _statusFromTime() internal view returns (BountyStatus) {
        if (block.timestamp < paras.applyDeadline) {
            return BountyStatus.ReadyToWork;
        } else {
            return BountyStatus.Expired;
        }
    }

    function _checkDepositLocker(address _address) internal view virtual {
        bool _isLocker = false;
        if (mappedDepositLockers[_address]) {
            if (timeLock == 0 || (timeLock > 0 && block.timestamp <= timeLock)) {
                _isLocker = true;
            }
        }
        require(_isLocker, "Caller is not allowed to lock");
    }

    function _checkDepositUnlocker(address _address) internal view virtual {
        bool _isUnlocker = false;
        if (mappedDepositUnlockers[_address]) {
            if (timeLock == 0 || (timeLock > 0 && block.timestamp <= timeLock)) {
                _isUnlocker = true;
            }
        } else if (timeLock > 0 && block.timestamp > timeLock && _address == founder) {
            _isUnlocker = true;
        }
        require(_isUnlocker, "Caller is not allowed to unlock");
    }

    function _checkFounder() internal view virtual {
        require(msg.sender == founder, "Caller is not the founder");
    }

    function _checkOthers() internal view virtual {
        require(msg.sender != factory, "Must not be factory");
        require(msg.sender != founder, "Must not be founder");
        require(msg.sender != thisAccount, "Must not be contractself");
        (bool _isApplicant,,uint8 _status) = _getApplicant(msg.sender);
        require((!_isApplicant)||(_isApplicant&&_status==uint8(ApplicantStatus.Withdraw)), "Must not be applicant");
    }

    function _checkAppliedApplicant() internal view virtual {
        (,,bool _isAppliedApplicant,) = _applicantState(msg.sender);
        require(_isAppliedApplicant, "Please apply first");
    }

    function _checkInApplyTime() internal view virtual {
        require(block.timestamp <= paras.applyDeadline, "Time past the application deadline");
    }

    function _checkBountyStatus(BountyStatus _status, string memory _errorMessage) internal view {
        require(bountyStatus == _status, _errorMessage);
    }

    function _checkNotBountyStatus(BountyStatus _status, string memory _errorMessage) internal view {
        require(bountyStatus != _status, _errorMessage);
    }

    function _applicantState(address _address) internal view returns (bool _isApplicant, bool _isApprovedApplicant,
        bool _isAppliedApplicant, uint256 _depositAmount) {
        (bool _isOrNot, uint256 _amount, uint8 _status) = _getApplicant(_address);
        _isApplicant = _isOrNot;
        _isApprovedApplicant = false;
        _isAppliedApplicant = false;
        if (_isApplicant) {
            if (_status == uint8(ApplicantStatus.Approved)) {
                _isApprovedApplicant = true;
            } else if (_status == uint8(ApplicantStatus.Applied)) {
                _isAppliedApplicant = true;
            }
        }
        _depositAmount = _amount;
    }

    function _whoIs(address _address) internal view returns (uint8, uint256, uint8) {
        uint8 _role = uint8(Role.Others);
        (bool _isApplicant, uint256 _depositAmount, uint8 _status) = _getApplicant(_address);
        if (_isApplicant) {
            _role = uint8(Role.Applicant);
        } else if (_address == founder) {
            _role = uint8(Role.Founder);
            _depositAmount = founderDepositAmount;
        }
        return (_role, _depositAmount, _status);
    }

    function _getApplicant(address _address) internal view returns (bool, uint256, uint8) {
        bool _isApplicant = true;
        uint256 _amount = mappedApplicants[_address].depositAmount;
        uint8 _status = uint8(mappedApplicants[_address].status);
        if (_amount == 0 && _status == 0) {
            _isApplicant = false;
        }
        return (_isApplicant, _amount, _status);
    }
}