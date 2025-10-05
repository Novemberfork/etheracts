use etheracts::ethrx::interface::{IEthrxDispatcher, IEthrxDispatcherTrait, IEthrxSafeDispatcher};
use etheracts::types::engraving::{Artifact, Engraving};
use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin_token::erc721::interface::{
    IERC721Dispatcher, IERC721DispatcherTrait, IERC721MetadataDispatcher,
    IERC721MetadataDispatcherTrait,
};
use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
use starknet::ContractAddress;
use crate::setup::BYSTANDER;

#[derive(Drop)]
pub struct EthrxFacade {
    pub contract_address: ContractAddress,
    pub dispatcher: IEthrxDispatcher,
    pub safe_dispatcher: IEthrxSafeDispatcher,
    pub ownable: IOwnableDispatcher,
    pub erc721_metadata: IERC721MetadataDispatcher,
    pub erc721: IERC721Dispatcher,
}

#[generate_trait]
pub impl EthrxFacadeImpl of EthrxTrait {
    fn new(contract_address: ContractAddress) -> EthrxFacade {
        let dispatcher = IEthrxDispatcher { contract_address };
        let safe_dispatcher = IEthrxSafeDispatcher { contract_address };
        let ownable = IOwnableDispatcher { contract_address };
        let erc721_metadata = IERC721MetadataDispatcher { contract_address };
        let erc721 = IERC721Dispatcher { contract_address };
        EthrxFacade {
            contract_address, dispatcher, safe_dispatcher, ownable, erc721_metadata, erc721,
        }
    }

    fn name(self: @EthrxFacade) -> ByteArray {
        self.erc721_metadata.name()
    }

    fn symbol(self: @EthrxFacade) -> ByteArray {
        self.erc721_metadata.symbol()
    }

    fn token_uri(self: @EthrxFacade, token_id: u256) -> ByteArray {
        self.erc721_metadata.token_uri(token_id)
    }

    fn owner_of(self: @EthrxFacade, token_id: u256) -> ContractAddress {
        self.erc721.owner_of(token_id)
    }


    fn mint_price(self: @EthrxFacade) -> u256 {
        (*self.dispatcher).mint_price()
    }

    fn mint_token(self: @EthrxFacade) -> ContractAddress {
        (*self.dispatcher).mint_token()
    }

    fn max_supply(self: @EthrxFacade) -> u256 {
        (*self.dispatcher).max_supply()
    }
    fn total_supply(self: @EthrxFacade) -> u256 {
        (*self.dispatcher).total_supply()
    }
    fn total_artifacts(self: @EthrxFacade) -> felt252 {
        (*self.dispatcher).total_artifacts()
    }
    fn token_id_to_artifact_id(self: @EthrxFacade, token_id: u256) -> felt252 {
        *self.token_ids_to_artifact_ids(array![token_id]).at(0)
    }

    fn token_ids_to_artifact_ids(self: @EthrxFacade, token_ids: Array<u256>) -> Array<felt252> {
        (*self.dispatcher).token_ids_to_artifact_ids(token_ids)
    }
    fn get_artifact(self: @EthrxFacade, token_id: u256) -> Artifact {
        (*self.dispatcher).get_artifacts(array![token_id])[0].clone()
    }
    fn get_artifacts(self: @EthrxFacade, token_ids: Array<u256>) -> Array<Artifact> {
        (*self.dispatcher).get_artifacts(token_ids)
    }
    fn artifact_tag_nonce(self: @EthrxFacade, artifact_id: felt252, tag: felt252) -> usize {
        *(*self.dispatcher).artifact_tag_nonces(array![artifact_id], array![tag]).at(0)
    }
    fn artifact_tag_nonces(
        self: @EthrxFacade, artifact_ids: Array<felt252>, tags: Array<felt252>,
    ) -> Array<usize> {
        (*self.dispatcher).artifact_tag_nonces(artifact_ids, tags)
    }
    fn get_historic_artifact(
        self: @EthrxFacade, artifact_id: felt252, tags: Array<felt252>, tag_nonces: Array<usize>,
    ) -> Artifact {
        (*self.dispatcher)
            .get_historic_artifacts(array![artifact_id], array![tags], array![tag_nonces])[0]
            .clone()
    }
    fn get_historic_artifacts(
        self: @EthrxFacade,
        artifact_ids: Array<felt252>,
        tags: Array<Array<felt252>>,
        tag_nonces: Array<Array<usize>>,
    ) -> Array<Artifact> {
        (*self.dispatcher).get_historic_artifacts(artifact_ids, tags, tag_nonces)
    }
    fn official_tags(self: @EthrxFacade) -> Array<felt252> {
        (*self.dispatcher).official_tags()
    }

    fn build_engraving(self: @EthrxFacade, tag: felt252, value: ByteArray) -> Engraving {
        Engraving { tag, data: value.into() }
    }

    fn mint_star(self: @EthrxFacade, to: ContractAddress) {
        self.mint_batch_star(array![to], array![1_u256]);
    }

    fn mint_batch_star(self: @EthrxFacade, tos: Array<ContractAddress>, amounts: Array<u256>) {
        assert!(amounts.len() == tos.len(), "Amounts and Tos length mismatch");

        // Calculate total cost
        let mut total_cost = 0_u256;
        for amount in amounts.clone() {
            total_cost += amount * self.mint_price();
        }

        // Approve spending
        start_cheat_caller_address(self.mint_token(), BYSTANDER);
        let erc20 = IERC20Dispatcher { contract_address: self.mint_token() };
        erc20.approve(*self.contract_address, total_cost);
        stop_cheat_caller_address(self.mint_token());

        // Mint
        start_cheat_caller_address(*self.contract_address, BYSTANDER);
        self.mint_batch(tos, amounts);
        stop_cheat_caller_address(*self.contract_address);
    }


    fn mint(self: @EthrxFacade, amount: u256, to: ContractAddress) {
        self.mint_batch(array![to], array![amount]);
    }

    fn mint_batch(self: @EthrxFacade, tos: Array<ContractAddress>, amounts: Array<u256>) {
        self.dispatcher.mint(amounts, tos);
    }

    fn engrave_star(self: @EthrxFacade, token_id: u256, artifact: Artifact) {
        self.engrave_batch_star(array![token_id], array![artifact]);
    }

    fn engrave_batch_star(self: @EthrxFacade, token_ids: Array<u256>, artifacts: Array<Artifact>) {
        for (token_id, artifact) in token_ids.into_iter().zip(artifacts) {
            let owner_of = self.owner_of(token_id);
            start_cheat_caller_address(*self.contract_address, owner_of);
            self.engrave(token_id, artifact);
            stop_cheat_caller_address(*self.contract_address);
        }
    }

    fn engrave(self: @EthrxFacade, token_id: u256, artifact: Artifact) {
        self.engrave_batch(array![token_id], array![artifact])
    }

    fn engrave_batch(self: @EthrxFacade, token_ids: Array<u256>, artifacts: Array<Artifact>) {
        self.dispatcher.engrave(token_ids, artifacts)
    }

    fn transfer(self: @EthrxFacade, from: ContractAddress, to: ContractAddress, token_id: u256) {
        self.transfer_batch(array![from], array![to], array![token_id]);
    }

    fn transfer_batch(
        self: @EthrxFacade,
        froms: Array<ContractAddress>,
        tos: Array<ContractAddress>,
        token_ids: Array<u256>,
    ) {
        assert!(
            froms.len() == tos.len() && tos.len() == token_ids.len(),
            "Froms, Tos and Token IDs length mismatch",
        );

        for i in 0..froms.len() {
            let from = *froms.at(i);
            let to = *tos.at(i);
            let token_id = *token_ids.at(i);
            self.erc721.transfer_from(from, to, token_id);
        }
    }

    fn transfer_star(
        self: @EthrxFacade, from: ContractAddress, to: ContractAddress, token_id: u256,
    ) {
        self.transfer_batch_star(array![from], array![to], array![token_id]);
    }

    fn transfer_batch_star(
        self: @EthrxFacade,
        froms: Array<ContractAddress>,
        tos: Array<ContractAddress>,
        token_ids: Array<u256>,
    ) {
        assert!(
            froms.len() == tos.len() && tos.len() == token_ids.len(),
            "Froms, Tos and Token IDs length mismatch",
        );

        for i in 0..froms.len() {
            let from = *froms.at(i);
            let to = *tos.at(i);
            let token_id = *token_ids.at(i);
            start_cheat_caller_address(*self.contract_address, from);
            self.erc721.transfer_from(from, to, token_id);
            stop_cheat_caller_address(*self.contract_address);
        }
    }

    fn transfer_with_engraving(
        self: @EthrxFacade, from: ContractAddress, to: ContractAddress, token_id: u256,
    ) {
        self.transfer_batch_with_engraving(array![from], array![to], array![token_id]);
    }

    fn transfer_batch_with_engraving(
        self: @EthrxFacade,
        froms: Array<ContractAddress>,
        tos: Array<ContractAddress>,
        token_ids: Array<u256>,
    ) {
        assert!(
            froms.len() == tos.len() && tos.len() == token_ids.len(),
            "Froms, Tos, Token IDs and Artifacts length mismatch",
        );

        self.dispatcher.transfer_and_save_artifact(froms, tos, token_ids);
    }

    fn transfer_with_engraving_star(
        self: @EthrxFacade, from: ContractAddress, to: ContractAddress, token_id: u256,
    ) {
        start_cheat_caller_address(*self.contract_address, from);
        self.transfer_with_engraving(from, to, token_id);
        stop_cheat_caller_address(*self.contract_address);
    }


    /// Ownable ///

    fn owner(self: @EthrxFacade) -> ContractAddress {
        (*self.ownable).owner()
    }

    fn transfer_ownership(self: @EthrxFacade, new_owner: ContractAddress) {
        self.ownable.transfer_ownership(new_owner);
    }

    fn renounce_ownership(self: @EthrxFacade) {
        self.ownable.renounce_ownership();
    }

    //fn transfer_and_save_artifact(
    //    self: @EthrxFacade,
    //    from: ContractAddress,
    //    to: ContractAddress,
    //    token_id: u256,
    //) {
    //    self.safe_dispatcher.transfer_and_save_artifact(array![from], array![to],
    //    array![token_id]);
    //}

    //fn transfer_and_save_artifact_batch(
    //    self: @EthrxFacade,
    //    froms: Array<ContractAddress>,
    //    tos: Array<ContractAddress>,
    //    token_ids: Array<u256>,
    //) {
    //    self.safe_dispatcher.transfer_and_save_artifact(froms, tos, token_ids);
    //}

    /// Admin ///

    fn set_base_uri(self: @EthrxFacade, new_base_uri: ByteArray) {
        self.dispatcher.set_base_uri(new_base_uri);
    }

    fn set_mint_price(self: @EthrxFacade, new_mint_price: u256) {
        self.dispatcher.set_mint_price(new_mint_price);
    }

    fn set_mint_token(self: @EthrxFacade, new_mint_token: ContractAddress) {
        self.dispatcher.set_mint_token(new_mint_token);
    }

    fn set_tags(
        self: @EthrxFacade,
        modify_tags: Option<Array<(usize, felt252)>>,
        new_tags: Option<Array<felt252>>,
    ) {
        self.dispatcher.set_tags(modify_tags, new_tags);
    }
}
