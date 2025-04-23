use core::starknet::ContractAddress;
use crate::utils::maths;

#[starknet::interface]
pub trait IERC20<TContractState> {
    fn get_name(self: @TContractState) -> felt252;
    fn get_symbol(self: @TContractState) -> felt252;
    fn get_decimals(self: @TContractState) -> u8;
    fn get_total_supply(self: @TContractState) -> felt252;
    fn balance_of(self: @TContractState, account: ContractAddress) -> felt252;
    fn allowance(
        self: @TContractState, owner: ContractAddress, spender: ContractAddress,
    ) -> felt252;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: felt252);
    fn transfer_from(
        ref self: TContractState,
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: felt252,
    );
    fn approve(ref self: TContractState, spender: ContractAddress, amount: felt252);
    fn increase_allowance(ref self: TContractState, spender: ContractAddress, added_value: felt252);
    fn decrease_allowance(
        ref self: TContractState, spender: ContractAddress, subtracted_value: felt252,
    );
}


#[starknet::interface]
pub trait ITulip<TContractState> {
    fn deposit(ref self: TContractState, amount: u256);
    fn withdraw(ref self: TContractState, shares: u256);
    
}

#[starknet::contract]
mod Tulip {
    use starknet::storage::StoragePathEntry;
    use super::maths;
    use super::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{get_block_timestamp, ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };

    const UPDATER_ROLE: felt252 = 'UPDATER_ROLE';
    const AGENT_ROLE: felt252 = 'AGENT_ROLE';
    const GOVERNMENT_ROLE: felt252 = 'GOVERNMENT_ROLE';
    const FEE_BASE: u256 = 10000;

    #[storage]
    struct Storage {
        token: IERC20Dispatcher,
        rate: u256,
        total_supply: u256,
        total_supply_locked_deprecated: u256,
        deposited: Map<ContractAddress, u256>,
        balance: Map<ContractAddress, u256>,
        balance_locked: Map<ContractAddress, u256>,
        nonce: u256,
        lastTimeUpdated: u64,
        l1_bridge: ContractAddress,
        fee: u256,
        beneficiary: ContractAddress,

    }

   
    #[external(v0)]
    pub fn init(
        ref self: ContractState, 
        _token: ContractAddress,
        _agent: ContractAddress,
    ) {
        self.token.write(IERC20Dispatcher { contract_address: _token });
        self.fee.write(50);
        self.rate.write(1000000000000000000);
    }

    #[external(v0)]
    pub fn deposit(ref self: ContractState, amount: u256) {
        let caller = get_caller_address();
        let this = get_contract_address();

        assert(amount > 0, 'Amount must be positive');

        let amount_felt252: felt252 = amount.low.into();
        self.token.read().transfer_from(caller, this, amount_felt252);
        let rate = self.rate.read();
        let amountLP = maths::u256_mul_div(amount, rate, 1000000000000000000, maths::Rounding::Ceil);
        self.deposited.entry(caller).write(self.deposited.entry(caller).read() + amount);
        self.balance.entry(caller).write(self.balance.entry(caller).read() + amountLP);
        self.total_supply.write(self.total_supply.read() + amountLP);
    }

    #[external(v0)]
    pub fn withdraw(ref self: ContractState, amountLP: u256) {
        let caller = get_caller_address();
        let this = get_contract_address();
        assert(amountLP > 0, 'Amount must be positive');
        assert(self.balance.entry(caller).read() >= amountLP, 'Insufficient LP balance');
        assert(self.total_supply.read() >= amountLP, 'Insufficient total supply'); 

        let amountToken = maths::u256_mul_div(amountLP,1000000000000000000 , FEE_BASE, maths::Rounding::Ceil);
        self.balance.entry(caller).write(self.balance.entry(caller).read() - amountLP);
        self.total_supply.write(self.total_supply.read() - amountLP);
        let amountFee = maths::u256_mul_div(amountToken, self.fee.read() , FEE_BASE, maths::Rounding::Ceil);
        let amountToken_felt252: felt252 = amountToken.low.into();
        let amountFee_felt252: felt252 = amountFee.low.into();
        self.token.read().transfer(caller, amountToken_felt252 - amountFee_felt252);
        self.token.read().transfer(self.beneficiary.read(), amountFee_felt252);
    }

    #[external(v0)]
    pub fn updateRate(ref self: ContractState, newRate: u256) {
        let oldRate = self.rate.read();
        self.rate.write(newRate);
        self.lastTimeUpdated.write(get_block_timestamp());
    }

    #[external(v0)]
    pub fn setFee(ref self: ContractState, newFee: u256) {
        assert(newFee <= 1000, 'Fee must be less than 10%');
        let oldFee = self.fee.read();
        self.fee.write(newFee);
    }

    
    fn _checkFeeBridge(ref self: ContractState, amount: u256, destAmount: u256) {
        let feeBridge = amount - destAmount;
        assert(feeBridge <= amount / 100, 'Bridge fee too high');

    }

}
