use starknet::ContractAddress;

#[starknet::interface]
pub trait IMintable<TState> {
    fn mint(ref self: TState, to: ContractAddress, amount: u256);
}

#[starknet::contract]
pub mod MockERC20 {
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    // External
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;

    // Internal
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, name: ByteArray, symbol: ByteArray) {
        self.erc20.initializer(name, symbol);
    }

    impl ERC20ImmutableConfigImpl of ERC20Component::ImmutableConfig {
        const DECIMALS: u8 = 6;
    }

    #[abi(embed_v0)]
    impl MintableImpl of super::IMintable<ContractState> {
        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            self.erc20.mint(to, amount);
        }
    }
}
