#[starknet::contract]
pub mod Ethrx {
    use alexandria_bytes::{Bytes, BytesStore};
    use core::num::traits::Zero;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use openzeppelin_token::erc721::ERC721Component;
    use openzeppelin_token::erc721::ERC721Component::Errors as ERC721Errors;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use crate::ethrx::interface::{ConstructorArgs, IEthrx};
    use crate::types::engraving::{Artifact, Engraving, INITIAL_ENGRAVINGS};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);


    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        mint_token: ContractAddress,
        mint_price: u256,
        max_supply: u256,
        total_tokens: u256,
        artifact_nonces: felt252,
        token_artifact_ids: Map<u256, felt252>,
        tag_registry: Map<usize, felt252>,
        total_registered_tags: usize,
        tag_nonces: Map<(felt252, felt252), usize>,
        artifacts: Map<(felt252, felt252, usize), Bytes>,
        artifact_saving: Map<u256, bool>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[constructor]
    fn constructor(ref self: ContractState, args: ConstructorArgs) {
        let ConstructorArgs {
            owner, name, symbol, base_uri, mint_token, mint_price, max_supply,
        } = args;

        self.ownable.initializer(owner);
        self.erc721.initializer(name, symbol, base_uri);

        self.mint_token.write(mint_token);
        self.mint_price.write(mint_price);
        self.max_supply.write(max_supply);

        self._mint_and_engrave_initial_artifacts(owner);
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ArtifactEngraved: ArtifactEngraved,
        TagRegistered: TagRegistered,
        TagReregistered: TagReregistered,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TagReregistered {
        pub old_tag: felt252,
        pub new_tag: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TagRegistered {
        pub new_tag: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ArtifactEngraved {
        pub token_id: u256,
        pub old_engraving: Engraving,
        pub new_engraving: Engraving,
    }

    impl EthrxHooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            let mut self = self.get_contract_mut();

            // @dev If this is a transfer that saves the artifact, do not wipe it
            if !self.artifact_saving.entry(token_id).read() {
                self._wipe_artifact(token_id);
                return;
            }
        }
    }

    #[abi(embed_v0)]
    impl EthrxImpl of IEthrx<ContractState> {
        /// READ ///
        fn mint_price(self: @ContractState) -> u256 {
            self.mint_price.read()
        }

        fn mint_token(self: @ContractState) -> ContractAddress {
            self.mint_token.read()
        }

        fn max_supply(self: @ContractState) -> u256 {
            self.max_supply.read()
        }

        fn total_supply(self: @ContractState) -> u256 {
            self.total_tokens.read()
        }

        fn total_artifacts(self: @ContractState) -> felt252 {
            self.artifact_nonces.read()
        }

        fn token_ids_to_artifact_ids(
            self: @ContractState, token_ids: Array<u256>,
        ) -> Array<felt252> {
            token_ids.into_iter().map(|id| self.token_artifact_ids.entry(id).read()).collect()
        }

        fn artifact_tag_nonces(
            self: @ContractState, artifact_ids: Array<felt252>, tags: Array<felt252>,
        ) -> Array<usize> {
            assert!(artifact_ids.len() == tags.len(), "Mismatched lengths");
            artifact_ids
                .into_iter()
                .zip(tags)
                .map(
                    |key| {
                        let (artifact_id, tag) = key;
                        self.tag_nonces.entry((artifact_id, tag)).read()
                    },
                )
                .collect()
        }

        fn get_artifacts(self: @ContractState, token_ids: Array<u256>) -> Array<Artifact> {
            let official_tags = @self.official_tags();

            let mut artifacts: Array<Artifact> = array![];
            for token_id in token_ids {
                let artifact_id = self.token_artifact_ids.entry(token_id).read();
                let nonce_list = self._get_artifact_nonces(artifact_id, official_tags);

                artifacts.append(self._lookup_artifact(artifact_id, official_tags, @nonce_list));
            }
            artifacts
        }

        fn get_historic_artifacts(
            self: @ContractState,
            artifact_ids: Array<felt252>,
            tags: Array<Array<felt252>>,
            tag_nonces: Array<Array<usize>>,
        ) -> Array<Artifact> {
            assert!(artifact_ids.len() == tags.len(), "Mismatched lengths");
            assert!(tags.len() == tag_nonces.len(), "Mismatched lengths");

            let mut artifacts: Array<Artifact> = array![];
            for i in 0..tags.len() {
                let artifact_id = *artifact_ids.at(i);
                let tag_list = tags.at(i);
                let nonce_list = tag_nonces.at(i);

                artifacts.append(self._lookup_artifact(artifact_id, tag_list, nonce_list));
            }
            artifacts
        }


        /// WRITE ///

        fn mint(ref self: ContractState, amounts: Array<u256>, tos: Array<ContractAddress>) {
            assert!(amounts.len() == tos.len(), "Mismatched lengths");

            for (amount, to) in amounts.into_iter().zip(tos) {
                self._mint(to, amount, true);
            }
        }

        fn engrave(ref self: ContractState, token_ids: Array<u256>, artifacts: Array<Artifact>) {
            assert!(token_ids.len() == artifacts.len(), "Mismatched lengths");

            for i in 0..token_ids.len() {
                let token_id = *token_ids[i];
                let artifact = artifacts.at(i).clone();

                assert!(self.owner_of(token_id) == get_caller_address(), "Not token owner");

                self._engrave_artifact(token_id, artifact, true);
            }
        }

        fn transfer_and_save_artifact(
            ref self: ContractState,
            froms: Array<ContractAddress>,
            tos: Array<ContractAddress>,
            token_ids: Array<u256>,
        ) {
            assert!(
                froms.len() == tos.len() && froms.len() == token_ids.len(), "Mismatched lengths",
            );

            for i in 0..token_ids.len() {
                let from = *froms[i];
                let to = *tos[i];
                let token_id = *token_ids[i];

                self._transfer_with_engraving(from, to, token_id);
            }
        }

        fn set_base_uri(ref self: ContractState, new_base_uri: ByteArray) {
            self._only_owner();
            self.erc721._set_base_uri(new_base_uri);
        }

        fn set_mint_price(ref self: ContractState, new_mint_price: u256) {
            self._only_owner();
            self.mint_price.write(new_mint_price);
        }

        fn set_mint_token(ref self: ContractState, new_mint_token: ContractAddress) {
            self._only_owner();
            self.mint_token.write(new_mint_token);
        }

        fn set_tags(
            ref self: ContractState,
            modify_tags: Option<Array<(usize, felt252)>>,
            new_tags: Option<Array<felt252>>,
        ) {
            self._only_owner();

            if let Option::Some(tag_fixes) = modify_tags {
                let total_registered_tags = self.total_registered_tags.read();

                for tag_fixes in tag_fixes {
                    let (index, new_tag) = tag_fixes;

                    assert!(index <= total_registered_tags, "Index out of bounds");

                    let old_tag = self.tag_registry.entry(index).read();

                    self.tag_registry.entry(index).write(new_tag);
                    self.emit(Event::TagReregistered(TagReregistered { old_tag, new_tag }));
                }
            }

            if let Option::Some(tags) = new_tags {
                let mut total_registered_tags = self.total_registered_tags.read();

                for new_tag in tags {
                    total_registered_tags += 1;

                    self.total_registered_tags.write(total_registered_tags);
                    self.tag_registry.entry(total_registered_tags).write(new_tag);
                    self.emit(Event::TagRegistered(TagRegistered { new_tag }));
                }
            }
        }

        fn official_tags(self: @ContractState) -> Array<felt252> {
            let total_registered_tags: u256 = self.total_registered_tags.read().into();
            let mut tags: Array<felt252> = array![];
            for i in 1..=total_registered_tags {
                let tag = self.tag_registry.entry(i.try_into().unwrap()).read();
                tags.append(tag);
            }
            tags
        }
    }

    #[generate_trait]
    impl InternalImpl of EthrxInternalTrait {
        fn _get_artifact_nonces(
            self: @ContractState, artifact_id: felt252, tags: @Array<felt252>,
        ) -> Array<usize> {
            (tags)
                .into_iter()
                .map(|tag| self.tag_nonces.entry((artifact_id, *tag)).read())
                .collect()
        }

        fn _lookup_artifact(
            self: @ContractState,
            artifact_id: felt252,
            tags: @Array<felt252>,
            tag_nonces: @Array<usize>,
        ) -> Artifact {
            assert!(tags.len() == tag_nonces.len(), "Mismatched lengths");

            let collection: Array<Engraving> = tags
                .into_iter()
                .zip(tag_nonces)
                .map(
                    |tag_nonce| {
                        let (tag, nonce) = tag_nonce;
                        Engraving {
                            tag: *tag,
                            data: self.artifacts.entry((artifact_id, *tag, *nonce)).read(),
                        }
                    },
                )
                .collect();

            Artifact { collection }
        }


        fn _only_owner(ref self: ContractState) {
            assert!(get_caller_address() == self.owner(), "Ownable: caller is not the owner");
        }

        fn _register_tags(ref self: ContractState, new_tags: Array<felt252>) {
            let mut total_registered_tags = self.total_registered_tags.read();

            for new_tag in new_tags {
                total_registered_tags += 1;

                self.total_registered_tags.write(total_registered_tags);
                self.tag_registry.entry(total_registered_tags).write(new_tag);
                self.emit(Event::TagRegistered(TagRegistered { new_tag }));
            }
        }

        fn _mint(ref self: ContractState, to: ContractAddress, amount: u256, is_paying: bool) {
            let total_tokens = self.total_tokens.read();

            let mut cost: u256 = 0;
            for i in 0..amount {
                let new_token_id = total_tokens + i + 1;
                if new_token_id <= self.max_supply.read() {
                    self.erc721.mint(to, new_token_id);
                    if is_paying {
                        cost += self.mint_price.read();
                    }
                    self.total_tokens.write(new_token_id);
                }
            }

            if cost > 0 {
                let mint_token = ERC20ABIDispatcher { contract_address: self.mint_token.read() };
                mint_token.transfer_from(get_caller_address(), self.owner(), cost);
            }
        }

        // @dev Copy of `ERC721Component::transfer_from` with 2 custom lines
        fn _transfer_with_engraving(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256,
        ) {
            assert(!to.is_zero(), ERC721Errors::INVALID_RECEIVER);

            self.artifact_saving.entry(token_id).write(true); // <- @dev Custom line 1
            let previous_owner = self.erc721.update(to, token_id, get_caller_address());
            self.artifact_saving.entry(token_id).write(false); // <- @dev Custom line 2

            assert(from == previous_owner, ERC721Errors::INVALID_SENDER);
        }

        fn _wipe_artifact(ref self: ContractState, token_id: u256) {
            let new_id: felt252 = self.artifact_nonces.read() + 1;

            self.artifact_nonces.write(new_id);
            self.token_artifact_ids.entry(token_id).write(new_id);
        }

        fn _engrave_artifact(
            ref self: ContractState, token_id: u256, artifact: Artifact, emit_event: bool,
        ) {
            let artifact_id: felt252 = self.token_artifact_ids.entry(token_id).read();
            assert!(artifact_id != 0, "Token does not exist");

            for new_engraving in artifact.collection {
                let nonce = self.tag_nonces.entry((artifact_id, new_engraving.tag)).read();

                let old_data = self.artifacts.entry((artifact_id, new_engraving.tag, nonce)).read();

                self.tag_nonces.entry((artifact_id, new_engraving.tag)).write(nonce + 1);
                self
                    .artifacts
                    .entry((artifact_id, new_engraving.tag, nonce + 1))
                    .write(new_engraving.data.clone());
                if emit_event {
                    self
                        .emit(
                            Event::ArtifactEngraved(
                                ArtifactEngraved {
                                    token_id,
                                    old_engraving: Engraving {
                                        tag: new_engraving.tag, data: old_data,
                                    },
                                    new_engraving,
                                },
                            ),
                        );
                }
            }
        }

        fn _mint_and_engrave_initial_artifacts(ref self: ContractState, owner: ContractAddress) {
            self._register_tags(INITIAL_ENGRAVINGS::INITIAL_TAGS());
            self._mint(owner, 11, false);

            for i in 1..=11_u256 {
                self._engrave_artifact(i, INITIAL_ENGRAVINGS::INITIAL_ARTIFACT(i), false);
            }
        }
    }
}
