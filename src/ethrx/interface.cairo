use alexandria_bytes::BytesStore;
use starknet::{ClassHash, ContractAddress};
use crate::types::engraving::Artifact;

#[derive(Drop, Serde)]
pub struct ConstructorArgs {
    pub owner: ContractAddress,
    pub name: ByteArray,
    pub symbol: ByteArray,
    pub base_uri: ByteArray,
    pub contract_uri: ByteArray,
    pub mint_token: ContractAddress,
    pub mint_price: u256,
    pub max_supply: u256,
}

#[starknet::interface]
pub trait IEthrx<TState> {
    /// READ ///
    fn is_minting(self: @TState) -> bool;
    fn mint_price(self: @TState) -> u256;
    fn mint_token(self: @TState) -> ContractAddress;
    fn max_supply(self: @TState) -> u256;

    fn total_artifacts(self: @TState) -> felt252;
    fn token_ids_to_artifact_ids(self: @TState, token_ids: Array<u256>) -> Array<felt252>;

    // Latest official artifact for each token
    fn get_artifacts(self: @TState, token_ids: Array<u256>) -> Array<Artifact>;

    // Historic artifacts (official and non-official)
    fn artifact_tag_nonces(
        self: @TState, artifact_ids: Array<felt252>, tags: Array<felt252>,
    ) -> Array<usize>;
    fn get_historic_artifacts(
        self: @TState,
        artifact_ids: Array<felt252>,
        tags: Array<Array<felt252>>,
        tag_nonces: Array<Array<usize>>,
    ) -> Array<Artifact>;

    fn contract_uri(self: @TState) -> ByteArray;
    fn contractURI(self: @TState) -> ByteArray;

    fn official_tags(self: @TState) -> Array<felt252>;

    fn version(self: @TState) -> usize;

    /// WRITE ///
    fn mint(ref self: TState, amounts: Array<u256>, tos: Array<ContractAddress>);

    fn engrave(ref self: TState, token_ids: Array<u256>, artifacts: Array<Artifact>);

    fn transfer_and_save_artifact(
        ref self: TState,
        froms: Array<ContractAddress>,
        tos: Array<ContractAddress>,
        token_ids: Array<u256>,
    );

    fn transfer_batch(ref self: TState, tos: Array<ContractAddress>, token_ids: Array<u256>);

    fn set_base_uri(ref self: TState, new_base_uri: ByteArray);
    fn set_contract_uri(ref self: TState, new_contract_uri: ByteArray);
    fn set_mint_price(ref self: TState, new_mint_price: u256);
    fn set_mint_token(ref self: TState, new_mint_token: ContractAddress);
    fn set_minting(ref self: TState, enabled: bool);
    fn set_tags(
        ref self: TState,
        modify_tags: Option<Array<(usize, felt252)>>,
        new_tags: Option<Array<felt252>>,
    );
    fn upgrade_contract(ref self: TState, new_class_hash: ClassHash);
}
