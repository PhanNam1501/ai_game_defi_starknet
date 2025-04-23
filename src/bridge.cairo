use starknet::ClassHash;
use starknet::ContractAddress;
use starknet::EthAddress;

#[starknet::interface]
trait IERC20<TContractState> {
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
trait ITokenBridge<TContractState> {
    fn get_version(self: @TContractState) -> felt252;
    fn get_identity(self: @TContractState) -> felt252;
    fn get_l1_token(self: @TContractState, l2_token: ContractAddress) -> EthAddress;
    fn get_l1_bridge(self: @TContractState) -> EthAddress;
    fn get_l2_token(self: @TContractState, l1_token: EthAddress) -> ContractAddress;
    fn get_remaining_withdrawal_quota(self: @TContractState, l1_token: EthAddress) -> u256;
    fn initiate_withdraw(ref self: TContractState, l1_recipient: EthAddress, amount: u256);
    fn initiate_token_withdraw(
        ref self: TContractState, l1_token: EthAddress, l1_recipient: EthAddress, amount: u256,
    );
}


#[starknet::interface]
pub trait Ibridge<TContractState> { 
    fn init(ref self: TContractState, amount: u256, l2_bridge: ContractAddress, l2_token: ContractAddress);
    fn withdraw(ref self: TContractState, amount: u256, l1_recipient: EthAddress, l2_bridge: ContractAddress, l2_token: ContractAddress);
}

#[starknet::contract]
mod bridge {
    use super::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::syscalls;
    use starknet::{ContractAddress, get_caller_address, get_contract_address, EthAddress};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use super::{ITokenBridgeDispatcher, ITokenBridgeDispatcherTrait};
    #[storage]
    struct Storage {
        l2_bridge: ITokenBridgeDispatcher,
        l2_token: IERC20Dispatcher,
    }


    #[abi(embed_v0)] 
    impl bridgeImpl of super::Ibridge<ContractState> {
        fn init(ref self: ContractState, amount: u256, l2_bridge: ContractAddress, l2_token: ContractAddress) {
            let caller = get_caller_address();
            let this = get_contract_address();
            self.l2_bridge.write(ITokenBridgeDispatcher { contract_address: l2_bridge});
            self.l2_token.write(IERC20Dispatcher { contract_address: l2_token});
            self.l2_token.read().approve(l2_bridge, amount);
            self.l2_token.read().transfer_from(caller, this, amount * 2);
        }
        fn withdraw(ref self: ContractState, amount: u256, l1_recipient: EthAddress, l2_bridge: ContractAddress, l2_token: ContractAddress) {
            let caller = get_caller_address();
            let this = get_contract_address();
            self.l2_bridge.write(ITokenBridgeDispatcher { contract_address: l2_bridge});
            self.l2_token.write(IERC20Dispatcher { contract_address: l2_token});
            let amount_felt252: felt252 = amount.low.into();
            self.l2_token.read().transfer_from(caller, this, amount * 2);
            self.l2_token.read().approve(l2_bridge, amount * 2);
            self.l2_bridge.read().initiate_withdraw(l1_recipient, amount);
        }
        
    }
    

    

    

}