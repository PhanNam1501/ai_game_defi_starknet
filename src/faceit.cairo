use core::starknet::{ContractAddress, Event};
use starknet::EthAddress;
use crate::utils::maths;

#[starknet::interface]
pub trait IERC20<TContractState> {
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn decimals(self: @TContractState) -> u8;
    fn total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    ) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    fn increase_allowance(
        ref self: TContractState, spender: ContractAddress, added_value: u256,
    ) -> bool;
    fn decrease_allowance(
        ref self: TContractState, spender: ContractAddress, subtracted_value: u256,
    ) -> bool;
}

#[starknet::interface]
pub trait Itulip<TContractState> {
    fn deposit(ref self: TContractState, amount: u256);
    fn withdraw(ref self: TContractState, amountLP: u256, user: ContractAddress);
    fn init(
        ref self: TContractState,
        _token: ContractAddress,
        _agent: ContractAddress,
        _goverment: ContractAddress,
    );
    fn transferToTreasury(
        ref self: TContractState,
        amount: u256,
        l1_recipient: EthAddress,
        l2_bridge: ContractAddress,
        l2_token: ContractAddress,
    );
    fn changeGovernment(ref self: TContractState, newGovernment: ContractAddress);
    fn updateRate(ref self: TContractState, newRate: u256);
    fn setFee(ref self: TContractState, newFee: u256);
    fn _checkFeeBridge(ref self: TContractState, amount: u256, destAmount: u256);
    fn getBalance(ref self: TContractState, user: ContractAddress) -> u256;
    fn getDeposited(ref self: TContractState, user: ContractAddress) -> u256;
}

#[starknet::interface]
pub trait Ifaceit<TContractState> {
    fn init(ref self: TContractState,  _token: ContractAddress, _vault: ContractAddress);
    fn register( ref self: TContractState ) -> u256;
    fn raiseFund( ref self: TContractState, gameId: u256, amountToken: u256);
}

#[starknet::contract]
mod faceit {
    use starknet::EthAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};
    use super::{
        IERC20Dispatcher, IERC20DispatcherTrait, maths, IfaceitDispatcher, IfaceitDispatcherTrait, ItulipDispatcher, ItulipDispatcherTrait
    };

    #[storage]
    struct Storage {
        token: IERC20Dispatcher,
        vault: ItulipDispatcher,
        gameId: u256,
        totalFund: u256,
        balance: Map<u256, Map<ContractAddress, u256>>,
        totalFundEachCompetition: Map<u256, u256>,
        hostCompetition: Map<u256, ContractAddress>,
        isCompleted: bool
    }

    #[abi(embed_v0)]
    impl faceitImpl of super::Ifaceit<ContractState> {
        fn init(ref self: ContractState,  _token: ContractAddress, _vault: ContractAddress) {
            self.token.write(IERC20Dispatcher { contract_address: _token });
            self.vault.write(ItulipDispatcher { contract_address: _vault});
        }
        fn register( ref self: ContractState) -> u256 {
            let caller = get_caller_address();
            let id = self.gameId.read();
            self.hostCompetition.entry(id).write(caller);
            self.gameId.write(id + 1);
            self.isCompleted.write(false);
            return id;
        }

        fn raiseFund( ref self: ContractState, gameId: u256, amountToken: u256) {
            let caller = get_caller_address();
            self.vault.read().deposit(amountToken);
            self.balance.entry(gameId).entry(caller).write(amountToken);
            self.totalFundEachCompetition.entry(gameId).write(self.totalFundEachCompetition.entry(gameId).read() + amountToken);
            self.totalFund.write(self.totalFund.read() + amountToken);
        }


    }
}