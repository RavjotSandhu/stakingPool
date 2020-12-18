pragma solidity ^0.7.0;

interface IDepositContract {
    function deposit(
        bytes calldata pubkey,
        bytes calldata withdrawal_credentials,
        bytes calldata signature,
        bytes32 deposit_data_root
    ) external payable;
}

contract stakingPool {
    mapping(address => uint) public balances;
    mapping(bytes => bool) public publicKeysUsed;
    IDepositContract public depositContract = IDepositContract(0x00000000219ab540356cBB839Cbe05303d7705Fa);
    address public admin;
    uint public end;
    bool public finalized;
    uint public totalInvested;
    uint public totalChange;
    mapping(address => bool) public changeClaimed;
    
    //allows investor to withdraw investment on ethereum 2.0
    event newInvestor (
        address investor
    );

    constructor() {
        admin = msg.sender;
        end = block.timestamp + 14 days;
    }

    //to allow investor to invest in eth
    function invest() external payable {
        require(block.timestamp < end, 'too late');//make sure that we haven't reached the end of the investment period
        //if the current investor is new and has never invested before
        if(balances[msg.sender] == 0) {
            emit newInvestor(msg.sender);   
        }
        balances[msg.sender] += msg.value;
    }

    function finalize() external {
        require(block.timestamp >= end, 'too early');
        require(finalized == false, 'already finalized');
        finalized = true;
        totalInvested = address(this).balance;
        totalChange = address(this).balance % 32 ether;
    }

    function getChange() external {
        require(finalized == true, 'not finalized');
        require(balances[msg.sender] > 0, 'not an investor');
        require(changeClaimed[msg.sender] == false, 'change already claimed');
        changeClaimed[msg.sender] = true;
        uint amount = totalChange * balances[msg.sender] / totalInvested;
        msg.sender.transfer(amount);
    }
    //we get this from eth2.0 deposit_contract.sol
    function deposit(
        bytes calldata pubkey,
        bytes calldata withdrawal_credentials,
        bytes calldata signature,
        bytes32 deposit_data_root
    )
        external{
            require(finalized == true, 'too early');
            require(msg.sender == admin, 'only admin');
            require(address(this).balance >= 32 ether);
            require(publicKeysUsed[pubkey] == false, 'this pubkey was already used');
            depositContract.deposit{value: 32 ether}(
                pubkey, 
                withdrawal_credentials, 
                signature, 
                deposit_data_root
            );
        }
}