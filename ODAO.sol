/**
 *Submitted for verification at BscScan.com on 2022-02-23
*/

/**
 *Submitted for verification at BscScan.com on 2021-10-04
*/

//SPDX-License-Identifier: MIT
//Dev @interfinetwork

pragma solidity =0.6.12;

interface IBEP20 {
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
    event Burn(address indexed owner, address indexed to, uint value);
}

library SafeMath {
    function add(uint a, uint b) internal pure returns (uint) {
        uint c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }
    function sub(uint a, uint b) internal pure returns (uint) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        require(b <= a, errorMessage);
        uint c = a - b;

        return c;
    }
    function mul(uint a, uint b) internal pure returns (uint) {
        if (a == 0) {
            return 0;
        }

        uint c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }
    function div(uint a, uint b) internal pure returns (uint) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint c = a / b;

        return c;
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }
}


library Address {
    function isContract(address account) internal view returns (bool) {
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != 0x0 && codehash != accountHash);
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract BEP20 is Context, Ownable, IBEP20 {
    using SafeMath for uint;
    using Address for address;

    mapping (address => uint) internal _balances;
    mapping (address => mapping (address => uint)) internal _allowances;
    mapping (address => bool) private _isExcluded;
    mapping (address => bool) public isMarketPair;

    uint public totalBurn;
    
    uint internal _totalSupply;

    uint256 public _taxFee = 10;
    uint256 public _burnFee = 5;
    uint256 public _lpFee = 5;
    bool    public _sellFeeEnable = true;
    bool    public _buyFeeEnable = false;

    address public LPLiquidity = 0x32BDc76baC881d1c7CF79255934abcb74E0D4bbF;
    address public DeadAddress = 0x000000000000000000000000000000000000dEaD;

    constructor () internal {
        _isExcluded[owner()] = true;
        _isExcluded[LPLiquidity] = true;
        isMarketPair[DeadAddress] = true;
    }
  
    function totalSupply() public view override returns (uint) {
        return _totalSupply;
    }
    function balanceOf(address account) public view override returns (uint) {
        return _balances[account];
    }
    function transfer(address recipient, uint amount) public override  returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    function allowance(address towner, address spender) public view override returns (uint) {
        return _allowances[towner][spender];
    }
    function approve(address spender, uint amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function transferFrom(address sender, address recipient, uint amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance"));
        return true;
    }
    function increaseAllowance(address spender, uint addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }
    function decreaseAllowance(address spender, uint subtractedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "BEP20: decreased allowance below zero"));
        return true;
    }

    function _transfer(address sender, address recipient, uint amount) internal {
        require(sender != address(0), "BEP20: transfer from the zero address");

        _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance");

        uint256 netAmount = _takeFee(sender, recipient, amount);

        _balances[recipient] = _balances[recipient].add(netAmount);

        _burn(sender, recipient, amount);

        emit Transfer(sender, recipient, netAmount);
    }

    function _takeFee(address sender, address recipient, uint256 amount) internal returns (uint256 netAmount)  {

        uint256 tax = 0;

        if ((_buyFeeEnable && isMarketPair[sender]) || (_sellFeeEnable && isMarketPair[recipient])) {
            tax = amount.mul(_taxFee).div(100);
        }

        if (_isExcluded[sender] || _isExcluded[recipient]) {
            tax = 0;
        }

        netAmount = amount - tax;
   
        if (tax > 0) {
            _takeLiquidityFee(sender, LPLiquidity, tax);
            _takeBurnFee(sender, DeadAddress, tax);
        }
    }

    function _takeLiquidityFee(
        address sender,
        address recipient,
        uint256 tax) private {
        uint256 taxFans = tax.mul(_lpFee).div(_taxFee);
        _balances[recipient] = _balances[recipient].add(taxFans);
        emit Transfer(sender, recipient, taxFans);
    }

    function _takeBurnFee(
        address sender,
        address recipient,
        uint256 tax) private {
        uint256 taxFans = tax.mul(_burnFee).div(_taxFee);
        _balances[recipient] = _balances[recipient].add(taxFans);
        _burn(sender, recipient, taxFans);
        emit Transfer(sender, recipient, taxFans);
    }

    function _burn(address sender, address recipient, uint amount) private {
        if (recipient == address(0) || recipient == DeadAddress) {
            totalBurn = totalBurn.add(amount);
            _totalSupply = _totalSupply.sub(amount);

            emit Burn(sender, DeadAddress, amount);
        }
    }
 
    function _approve(address towner, address spender, uint amount) internal {
        require(towner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        _allowances[towner][spender] = amount;
        emit Approval(towner, spender, amount);
    }

    function excludeFrom(address account) external onlyOwner() {
        _isExcluded[account] = false;
    }

    function includeIn(address account) external onlyOwner() {
        _isExcluded[account] = true;
    }

    function setLiquidityAddr(address _addr) external onlyOwner {
      LPLiquidity = _addr;
    }

    function setMarketPairStatus(address account, bool newValue) external onlyOwner {
        isMarketPair[account] = newValue;
    }

    function getMarketPairStatus(address account) external view returns (bool) {
        return isMarketPair[account];
    }

    function setSellFeeEnable(bool newValue) external onlyOwner() {
        _sellFeeEnable = newValue;
    }

    function setBuyFeeEnable(bool newValue) external onlyOwner() {
        _buyFeeEnable = newValue;
    }
}

contract BEP20Detailed is BEP20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor (string memory tname, string memory tsymbol, uint8 tdecimals) BEP20() internal {
        _name = tname;
        _symbol = tsymbol;
        _decimals = tdecimals;
        
    }
    function name() public view returns (string memory) {
        return _name;
    }
    function symbol() public view returns (string memory) {
        return _symbol;
    }
    function decimals() public view returns (uint8) {
        return _decimals;
    }
}

contract ODAOToken is BEP20Detailed {

    constructor() BEP20Detailed("OriginDAO", "ODAO", 18) public {
        _totalSupply = 2600000 * (10**18);
    
	    _balances[_msgSender()] = _totalSupply;

	    emit Transfer(address(0), _msgSender(), _totalSupply);
    }
  
    function takeOutTokenInCase(address _token, uint256 _amount, address _to) public onlyOwner {
        IBEP20(_token).transfer(_to, _amount);
    }
}