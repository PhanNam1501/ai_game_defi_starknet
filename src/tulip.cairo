use core::starknet::{ContractAddress, Event};
use starknet::EthAddress;
use crate::utils::maths;


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
    fn handle_token_deposit(
        ref self: TContractState,
        from_address: felt252,
        l1_token: EthAddress,
        depositor: EthAddress,
        l2_recipient: ContractAddress,
        amount: u256,
    );
}


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
    fn requestWithdraw(ref self: TContractState, amount: u256, user: ContractAddress);
}

mod Events {
    use starknet::ContractAddress;
    #[derive(Drop, starknet::Event)]
    pub struct Deposited {
        pub user: ContractAddress,
        pub tokenAmount: u256,
        pub lpAmount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Withdrawn {
        pub user: ContractAddress,
        pub lpAmount: u256,
        pub tokenAmount: u256,
        pub feeAmount: u256
    }

    #[derive(Drop, starknet::Event)]
    pub struct RateUpdated {
        pub oldRate: u256,
        pub newRate: u256
    }

    #[derive(Drop, starknet::Event)]
    pub struct FeeUpdated {
        pub oldFee: u256,
        pub newFee: u256
    }

    #[derive(Drop, starknet::Event)]
    pub struct GovernmentChanged {
        pub oldGovernment: ContractAddress,
        pub newGovernment: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    pub struct RequestWithdraw {
        pub user: ContractAddress,
        pub amount: u256
    }
}


#[starknet::contract]
mod tulip {
    use AccessControlComponent::InternalTrait;
    use starknet::EthAddress;
    
    // use oppenzepplin::openzeppelin_access::accesscontrol::AccessControlComponent;
    use openzeppelin_access::accesscontrol::{AccessControlComponent};
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};
    use super::{
        IERC20Dispatcher, IERC20DispatcherTrait, ITokenBridgeDispatcher,
        ITokenBridgeDispatcherTrait, maths,
    };
    use super::Events;
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AccessControlEvent: AccessControlComponent::Event,
        SRC5Event: SRC5Component::Event,
        Deposited: Events::Deposited,
        Withdrawn: Events::Withdrawn,
        RateUpdated: Events::RateUpdated,
        FeeUpdated: Events::FeeUpdated,
        GovernmentChanged: Events::GovernmentChanged,
        RequestWithdraw: Events::RequestWithdraw

    }


    const UPDATER_ROLE: felt252 = selector!("UPDATER_ROLE");
    const AGENT_ROLE: felt252 = selector!("AGENT_ROLE");
    const GOVERNMENT_ROLE: felt252 = selector!("GOVERNMENT_ROLE");
    const FEE_BASE: u256 = 10000;

    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        token: IERC20Dispatcher,
        rate: u256,
        total_supply: u256,
        total_supply_locked_deprecated: u256,
        deposited: Map<ContractAddress, u256>,
        balance: Map<ContractAddress, u256>,
        balance_locked: Map<ContractAddress, u256>,
        lastTimeUpdated: u64,
        l1_bridge: ContractAddress,
        fee: u256,
        beneficiary: ContractAddress,
        _initialized: bool,
        l2_bridge: ITokenBridgeDispatcher,
        totalRequest: u256
    }


    #[constructor]
    fn constructor(ref self: ContractState) {
        self._initialized.write(false);
    }

    #[abi(embed_v0)]
    impl tulipImpl of super::Itulip<ContractState> {
        fn init(
            ref self: ContractState,
            _token: ContractAddress,
            _agent: ContractAddress,
            _goverment: ContractAddress,
        ) {
            assert(!self._initialized.read(), 'Initialized already');
            self._initialized.write(true);
            self.token.write(IERC20Dispatcher { contract_address: _token });
            self.fee.write(50);
            self.rate.write(1000000000000000000);
            self.beneficiary.write(_goverment);
            self.accesscontrol.initializer();
            self.accesscontrol._grant_role(AGENT_ROLE, _agent);
            self.accesscontrol._grant_role(GOVERNMENT_ROLE, _goverment);
            self.accesscontrol.set_role_admin(AGENT_ROLE, GOVERNMENT_ROLE);
            self.accesscontrol.set_role_admin(UPDATER_ROLE, GOVERNMENT_ROLE);
        }

        fn deposit(ref self: ContractState, amount: u256) {
            let caller = get_caller_address();
            let this = get_contract_address();

            assert(amount > 0, 'Amount must be positive');

            self.token.read().transfer_from(caller, this, amount);
            let rate = self.rate.read();
            let amountLP = maths::u256_mul_div(
                amount, rate, 1000000000000000000, maths::Rounding::Ceil,
            );
            self.deposited.entry(caller).write(self.deposited.entry(caller).read() + amount);
            self.balance.entry(caller).write(self.balance.entry(caller).read() + amountLP);
            self.total_supply.write(self.total_supply.read() + amountLP);
        }

        fn withdraw(ref self: ContractState, amountLP: u256, user: ContractAddress) {
            self.accesscontrol.assert_only_role(GOVERNMENT_ROLE);
            assert(amountLP > 0, 'Amount must be positive');
            assert(self.balance.entry(user).read() >= amountLP, 'Insufficient LP balance');
            assert(self.total_supply.read() >= amountLP, 'Insufficient total supply');

            let amountToken = maths::u256_mul_div(
                amountLP, 1000000000000000000, FEE_BASE, maths::Rounding::Ceil,
            );
            self.balance.entry(user).write(self.balance.entry(user).read() - amountLP);
            self.total_supply.write(self.total_supply.read() - amountLP);
            let amountFee = maths::u256_mul_div(
                amountToken, self.fee.read(), FEE_BASE, maths::Rounding::Ceil,
            );

            self.token.read().transfer(user, amountToken - amountFee);
            self.token.read().transfer(self.beneficiary.read(), amountFee);
        }

        fn requestWithdraw(ref self: ContractState, amount: u256, user: ContractAddress) {

        }

        fn transferToTreasury(
            ref self: ContractState,
            amount: u256,
            l1_recipient: EthAddress,
            l2_bridge: ContractAddress,
            l2_token: ContractAddress,
        ) {
            // let caller = get_caller_address();
            // let this = get_contract_address();
            self.accesscontrol.assert_only_role(AGENT_ROLE);
            self.l2_bridge.write(ITokenBridgeDispatcher { contract_address: l2_bridge });
            self.token.write(IERC20Dispatcher { contract_address: l2_token });
            self.token.read().approve(l2_bridge, amount);
            self.l2_bridge.read().initiate_withdraw(l1_recipient, amount);
        }

        fn changeGovernment(ref self: ContractState, newGovernment: ContractAddress) {
            self.accesscontrol.assert_only_role(GOVERNMENT_ROLE);
            let caller = get_caller_address();
            let oldGovernment = caller;
            self.accesscontrol._grant_role(GOVERNMENT_ROLE, newGovernment);
            self.accesscontrol._revoke_role(GOVERNMENT_ROLE, oldGovernment);
        }

        fn updateRate(ref self: ContractState, newRate: u256) {
            self.accesscontrol.assert_only_role(UPDATER_ROLE);
            assert(newRate <= self.rate.read(), 'new rate must be less or equal');
            assert(newRate > 0, 'Rate must be positive');
            let rate = self.rate.read();
            assert(
                newRate <= rate + (rate / 100) && newRate >= rate - (rate / 100),
                'new rate must be ',
            );
            let oldRate = rate;
            self.rate.write(newRate);
            self.lastTimeUpdated.write(get_block_timestamp());
        }

        fn setFee(ref self: ContractState, newFee: u256) {
            self.accesscontrol.assert_only_role(GOVERNMENT_ROLE);
            assert(newFee <= 1000, 'Fee must be less than 10%');
            let oldFee = self.fee.read();
            self.fee.write(newFee);
        }


        fn _checkFeeBridge(ref self: ContractState, amount: u256, destAmount: u256) {
            let feeBridge = amount - destAmount;
            assert(feeBridge <= amount / 100, 'Bridge fee too high');
        }

        fn getDeposited(ref self: ContractState, user: ContractAddress) -> u256 {
            self.deposited.entry(user).read()
        }

        fn getBalance(ref self: ContractState, user: ContractAddress) -> u256 {
            self.balance.entry(user).read()
        }
    }
}
