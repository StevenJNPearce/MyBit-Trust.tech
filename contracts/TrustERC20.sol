pragma solidity ^0.4.24;

import './SafeMath.sol';
import "./token/ERC20.sol";

// @title Trust contract
// @author Yossi Pik
// @notice This contract allows someone to leave ERC20 tokens for a beneficiary once expiration is reached
// @dev Can extend the beneficiary for multiple accounts by setting beneficiary to a multi-owned contract
contract TrustERC20 {
	using SafeMath for uint;

	address public trustor;        // Creator of the trust
	address public beneficiary;    // Recipient of the trust

	bool public revocable;      // Can the trustor revoke the trust?

	uint public expiration;    // Number of seconds until trust expires

	uint public trustBalance;    // Amount of tokens intended for beneficiary

	bool public alreadyDeposited;  // Has the trustor already put in the funds for the trust?

	ERC20 public token;		// The token to be used for the trust

	// @notice Constructor: Deploy Trust contract
	// @param (address) _mybitBurner = The contract address of the MyBitBurner
	// @param (address) _trustor = The address that is depositing tokens for the _beneficiary
	// @param (address) _beneficiary = The address of who is to receive the trustBalance
	// @param (bool) _revocable = Can the trustor revoke the contract at any point before the expiration?
	// @param (uint) _expiration = Number of seconds until the trust is redeemable
	// @param (address) _tokenContractAddress = The address of the contract of the token which should be used for the trust
	constructor(address _trustor, address _beneficiary, bool _revocable, uint _expiration, address _tokenContractAddress)
	public {
		trustor = _trustor;
		beneficiary = _beneficiary;
		revocable = _revocable;
		expiration = block.timestamp.add(_expiration);
		token = ERC20(_tokenContractAddress);
	}

	// @notice (payable) trustor can deposit tokens here once
	// @dev this function is called by the trustor
	// @param (uint) _amount = The amount of tokens to deposit to the Trust
	function depositTrust(uint _amount)
	external
	lessThan(0, _amount)
	lessThan(block.timestamp, expiration)
	payable {
		require(!alreadyDeposited);
		require(token.balanceOf(msg.sender) >= _amount);
		alreadyDeposited = true;
		trustBalance = trustBalance.add(_amount);
		token.transferFrom(msg.sender, address(this), _amount);
		emit LogDeposit(msg.sender, _amount);
	}

	// @notice trustor can revoke the contract if revocable == true
	function revoke()
	external
	lessThan(block.timestamp, expiration)
	onlySender(trustor)
	isRevocable {
		token.transfer(trustor, trustBalance);
		emit LogTrustRevoked(msg.sender, trustBalance);
		delete trustBalance;
		selfdestruct(msg.sender);
	}

	// @notice _beneficiary can withdraw trustBalance once expiration is reached
	function withdraw()
	external
	lessThan(expiration, block.timestamp)
	onlySender(beneficiary)
	returns (bool) {
		require(trustBalance > 0);
		uint amount = trustBalance;
		delete trustBalance;
		token.transfer(beneficiary, amount);
		emit LogWithdraw(beneficiary, amount);
		return true;
	}

	// @notice this allows the expiration of the trust to be changed to _numBlocks from block.timestamp
	// @param (uint) _seconds = Trust will expire in _seconds seconds
	function changeExpiration(uint _seconds) //Note: This should throw if change is a negative number
	external
	lessThan(block.timestamp, expiration)
	onlySender(trustor)
	isRevocable
	returns (bool){
		uint oldExpiration = expiration;
		expiration = block.timestamp.add(_seconds);
		emit LogExpirationChanged(oldExpiration, expiration);
		return true;
	}

	// @notice trustor can change the recipient of the trust if it has not yet expired
	// @param (address) _beneficiary = the address of the user to receive the Trust
	function changeBeneficiary(address _beneficiary)
	external
	lessThan(block.timestamp, expiration)
	onlySender(trustor)
	isRevocable
	returns (bool){
		require(_beneficiary != address(0));
		emit LogNewBeneficiary(beneficiary, _beneficiary);
		beneficiary = _beneficiary;
		return true;
	}

	// @notice fallback function. Rejects all ether
	function ()
	external
	payable {
		revert();
	}

	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//																						View Functions
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	// @notice helper function. Returns number of seconds until Trust expires
	function secUntilExpiration()
	external
	view
	returns (uint) {
		if (expiration < block.timestamp) { return 0; }
		return expiration.sub(block.timestamp);
	}

	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//																						Modifiers
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	// @notice reverts if _a >= _b
	modifier lessThan(uint _a, uint _b) {
		require(_a < _b);
		_;
	}

	// @notice reverts if msg.sender != _expectedCaller
	modifier onlySender(address _expectedCaller) {
		require(msg.sender == _expectedCaller);
		_;
	}

	// @notice reverts if trust is not revocable
	modifier isRevocable {
		require(revocable);
		_;
	}

	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//																						Events
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	event LogDeposit(address _sender, uint _amount);
	event LogWithdraw(address _beneficiary, uint _amount);
	event LogNewBeneficiary(address _oldBeneficiary, address _newBeneficiary);
	event LogTrustRevoked(address _trustor, uint _amount);
	event LogExpirationChanged(uint _oldExpiration, uint _newExpiration);

}
