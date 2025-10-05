use alexandria_bytes::BytesStore;
use starknet::ContractAddress;
use crate::types::engraving::{Artifact, Engraving};

#[derive(Drop, Serde)]
pub struct ConstructorArgs {
    pub owner: ContractAddress,
    pub name: ByteArray,
    pub symbol: ByteArray,
    pub base_uri: ByteArray,
    pub mint_token: ContractAddress,
    pub mint_price: u256,
    pub max_supply: u256,
}

#[starknet::interface]
pub trait IEthrx<TState> {
    /// READ ///
    fn mint_price(self: @TState) -> u256;
    fn mint_token(self: @TState) -> ContractAddress;
    fn max_supply(self: @TState) -> u256;
    fn total_supply(self: @TState) -> u256;

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

    fn official_tags(self: @TState) -> Array<felt252>;

    /// WRITE ///
    fn mint(ref self: TState, amounts: Array<u256>, tos: Array<ContractAddress>);

    fn engrave(ref self: TState, token_ids: Array<u256>, artifacts: Array<Artifact>);

    fn transfer_and_save_artifact(
        ref self: TState,
        froms: Array<ContractAddress>,
        tos: Array<ContractAddress>,
        token_ids: Array<u256>,
    );

    fn set_base_uri(ref self: TState, new_base_uri: ByteArray);
    fn set_mint_price(ref self: TState, new_mint_price: u256);
    fn set_mint_token(ref self: TState, new_mint_token: ContractAddress);
    fn set_tags(
        ref self: TState,
        modify_tags: Option<Array<(usize, felt252)>>,
        new_tags: Option<Array<felt252>>,
    );
}

#[starknet::interface]
pub trait IEthrxABI<TState> {
    /// Ethrx ///
    /// READ ///
    fn get_mint_price(self: @TState) -> u256;
    fn get_mint_token(self: @TState) -> ContractAddress;
    fn get_max_supply(self: @TState) -> u256;
    fn get_total_supply(self: @TState) -> u256;

    fn get_total_artifacts(self: @TState) -> felt252;
    fn get_token_artifact_ids(self: @TState, token_ids: Array<u256>) -> Array<felt252>;

    fn get_tag_nonces(
        self: @TState, artifact_ids: Array<felt252>, tags: Array<felt252>,
    ) -> Array<usize>;

    fn get_artifacts(self: @TState, token_ids: Array<u256>) -> Array<Array<Engraving>>;

    fn get_historic_artifacts(
        self: @TState,
        artifact_ids: Array<felt252>,
        tags: Array<Array<felt252>>,
        tag_nonces: Array<Array<usize>>,
    ) -> Array<Array<Engraving>>;

    fn get_registered_tags(self: @TState) -> Array<felt252>;

    /// WRITE ///
    fn mint(ref self: TState, amounts: Array<u256>, tos: Array<ContractAddress>);

    fn engrave(ref self: TState, token_ids: Array<u256>, engravings: Array<Array<Engraving>>);

    fn transfer_with_engraving(
        ref self: TState,
        froms: Array<ContractAddress>,
        tos: Array<ContractAddress>,
        token_ids: Array<u256>,
    );

    fn set_base_uri(ref self: TState, new_base_uri: ByteArray);
    fn set_mint_price(ref self: TState, new_mint_price: u256);
    fn set_mint_token(ref self: TState, new_mint_token: ContractAddress);
    fn register_tags(
        ref self: TState,
        modify_tags: Option<Array<(usize, felt252)>>,
        new_tags: Option<Array<felt252>>,
    );
    /// ERC721 ///
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn owner_of(self: @TState, token_id: u256) -> ContractAddress;
    fn safe_transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>,
    );
    fn transfer_from(ref self: TState, from: ContractAddress, to: ContractAddress, token_id: u256);
    fn approve(ref self: TState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @TState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TState, owner: ContractAddress, operator: ContractAddress,
    ) -> bool;
    // ISRC5
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;
    // IERC721Metadata
    fn name(self: @TState) -> ByteArray;
    fn symbol(self: @TState) -> ByteArray;
    fn token_uri(self: @TState, token_id: u256) -> ByteArray;
    // IERC721CamelOnly
    fn balanceOf(self: @TState, account: ContractAddress) -> u256;
    fn ownerOf(self: @TState, tokenId: u256) -> ContractAddress;
    fn safeTransferFrom(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        tokenId: u256,
        data: Span<felt252>,
    );
    fn transferFrom(ref self: TState, from: ContractAddress, to: ContractAddress, tokenId: u256);
    fn setApprovalForAll(ref self: TState, operator: ContractAddress, approved: bool);
    fn getApproved(self: @TState, tokenId: u256) -> ContractAddress;
    fn isApprovedForAll(self: @TState, owner: ContractAddress, operator: ContractAddress) -> bool;
    // IERC721MetadataCamelOnly
    fn tokenURI(self: @TState, tokenId: u256) -> ByteArray;

    /// Ownable ///
    fn owner(self: @TState) -> ContractAddress;
    fn renounce_ownership(ref self: TState);
    fn transfer_ownership(ref self: TState, new_owner: ContractAddress);
}
