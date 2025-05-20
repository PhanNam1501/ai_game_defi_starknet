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
pub trait Iapprove<TContractState> { 
    fn init(ref self: TContractState, amount: u256, l2_bridge: ContractAddress, l2_token: ContractAddress);
    fn withdraw(ref self: TContractState, amount: u256, l1_recipient: EthAddress, l2_bridge: ContractAddress, l2_token: ContractAddress);
}

#[starknet::contract]
mod approve {
    use super::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::syscalls;
    use starknet::{ContractAddress, get_caller_address, get_contract_address, EthAddress};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    #[storage]
    struct Storage {
        l2_token: IERC20Dispatcher,
    }


    #[abi(embed_v0)] 
    impl approveImpl of super::Iapprove<ContractState> {
        fn init(ref self: ContractState,  l2_token: ContractAddress, recipient: ContractAddress) {
            let caller = get_caller_address();
            let this = get_contract_address();
            
            self.l2_token.write(IERC20Dispatcher { contract_address: l2_token});
            self.l2_token.read().approve(recipient, amount * 2);
            self.l2_token.read().transfer_from(caller, this, amount * 2);
        }
        
        
    }
    

    

    

}