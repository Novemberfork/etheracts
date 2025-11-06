use alexandria_bytes::Bytes;
use core::num::traits::Zero;
use etheracts::ethrx::contract::Ethrx;
use etheracts::ethrx::interface::{IEthrxSafeDispatcher, IEthrxSafeDispatcherTrait};
use etheracts::types::engraving::{Artifact, Engraving, INITIAL_ENGRAVINGS};
use openzeppelin_token::erc20::ERC20Component;
use openzeppelin_token::erc20::interface::IERC20DispatcherTrait;
use openzeppelin_token::erc721::ERC721Component;
use snforge_std::{
    EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
};
use crate::setup::{
    ALICE, BASE_URI, BOB, BYSTANDER, CONTRACT_URI, MAX_SUPPLY, MINT_PRICE, NAME, OWNER, SYMBOL,
    setup,
};
use crate::utils::EthrxFacadeImpl;


#[test]
fn test_ethrx_constructor_args() {
    let (ethrx, erc20) = setup();

    assert!(ethrx.owner() == OWNER, "owner mismatch");
    assert!(ethrx.name() == NAME(), "name mismatch");
    assert!(ethrx.symbol() == SYMBOL(), "symbol mismatch");
    assert!(ethrx.token_uri(1) == format!("{}{}", BASE_URI(), 1), "base uri mismatch");
    assert!(ethrx.contract_uri() == CONTRACT_URI(), "contract uri mismatch");
    assert!(ethrx.mint_token() == erc20.contract_address, "mint token mismatch");
    assert!(ethrx.mint_price() == MINT_PRICE, "mint price mismatch");
    assert!(ethrx.max_supply() == MAX_SUPPLY, "max supply mismatch");
}

#[test]
fn test_ethrx_constructor() {
    let (ethrx, _) = setup();
    assert!(ethrx.total_supply() == 11, "initial total supply should be 11");
    for i in 1..=11_usize {
        assert!(ethrx.owner_of(i.into()) == OWNER, "initial token owner should be the deployer");
        assert!(
            ethrx.token_id_to_artifact_id(i.into()) == i.into(),
            "initial token artifact id should match token id",
        );
        // @dev !# finish once engravings moved in
        assert!(
            ethrx.get_artifact(i.into()) == INITIAL_ENGRAVINGS::INITIAL_ARTIFACT(i.into()),
            "initial artifact mismatch",
        );
    }
}


/// Test Helpers ///

#[test]
fn test_mint() {
    let (ethrx, erc20) = setup();

    let owner_balance_before = erc20.balance_of(OWNER);
    let alice_balance_before = erc20.balance_of(ALICE);
    let bystander_balance_before = erc20.balance_of(BYSTANDER);

    // Mint 1 token to Alice on behalf of Bystander
    let mut spy = spy_events();
    start_cheat_caller_address(erc20.contract_address, BYSTANDER);
    ethrx.mint_star(ALICE);
    stop_cheat_caller_address(erc20.contract_address);

    let owner_balance_after = erc20.balance_of(OWNER);
    let alice_balance_after = erc20.balance_of(ALICE);
    let bystander_balance_after = erc20.balance_of(BYSTANDER);

    assert!(ethrx.total_supply() == 12, "total supply should be 12 after minting 1 token");
    assert!(ethrx.owner_of(12) == ALICE, "newly minted token owner should be Alice");
    assert!(
        owner_balance_after == owner_balance_before + MINT_PRICE,
        "owner should receive the mint price",
    );
    assert!(
        bystander_balance_after == bystander_balance_before - MINT_PRICE,
        "Bystander's balance should decrease by the mint price",
    );
    assert!(alice_balance_after == alice_balance_before, "Alice's balance should remain unchanged");

    // Assert erc20 event
    spy
        .assert_emitted(
            @array![
                (
                    erc20.contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer { from: BYSTANDER, to: OWNER, value: MINT_PRICE },
                    ),
                ),
            ],
        );
    // Assert erc721 event
    spy
        .assert_emitted(
            @array![
                (
                    ethrx.contract_address,
                    ERC721Component::Event::Transfer(
                        ERC721Component::Transfer { from: Zero::zero(), to: ALICE, token_id: 12 },
                    ),
                ),
            ],
        );
}

#[test]
fn test_mint_batch() {
    let (ethrx, erc20) = setup();

    let owner_balance_before = erc20.balance_of(OWNER);
    let alice_balance_before = erc20.balance_of(ALICE);
    let bob_balance_before = erc20.balance_of(BOB);
    let bystander_balance_before = erc20.balance_of(BYSTANDER);

    let tos = array![ALICE, BOB];
    let amounts = array![2, 3];

    let mut spy = spy_events();
    ethrx.mint_batch_star(tos, amounts);

    let owner_balance_after = erc20.balance_of(OWNER);
    let alice_balance_after = erc20.balance_of(ALICE);
    let bob_balance_after = erc20.balance_of(BOB);
    let bystander_balance_after = erc20.balance_of(BYSTANDER);

    assert!(ethrx.total_supply() == 16, "total supply should be 16 after minting 5 tokens");
    for i in 12..=13_u256 {
        assert!(ethrx.owner_of(i) == ALICE, "token {i} owner should be Alice");
    }
    for i in 14..=16_u256 {
        assert!(ethrx.owner_of(i) == BOB, "token {i} owner should be Bob");
    }
    assert!(
        owner_balance_after == owner_balance_before + MINT_PRICE * 5,
        "owner should receive the mint price for 5 tokens",
    );
    assert!(
        bystander_balance_after == bystander_balance_before - MINT_PRICE * 5,
        "Alice's balance should decrease by the mint price for 3 tokens",
    );
    assert!(alice_balance_after == alice_balance_before, "Alice's balance should remain unchanged");
    assert!(bob_balance_after == bob_balance_before, "Bob's balance should remain unchanged");

    // Assert erc20 event
    spy
        .assert_emitted(
            @array![
                (
                    erc20.contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: BYSTANDER, to: OWNER, value: MINT_PRICE * 2,
                        },
                    ),
                ),
                (
                    erc20.contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: BYSTANDER, to: OWNER, value: MINT_PRICE * 3,
                        },
                    ),
                ),
            ],
        );
    // Assert erc721 events
    spy
        .assert_emitted(
            @array![
                (
                    ethrx.contract_address,
                    ERC721Component::Event::Transfer(
                        ERC721Component::Transfer { from: Zero::zero(), to: ALICE, token_id: 12 },
                    ),
                ),
                (
                    ethrx.contract_address,
                    ERC721Component::Event::Transfer(
                        ERC721Component::Transfer { from: Zero::zero(), to: ALICE, token_id: 13 },
                    ),
                ),
                (
                    ethrx.contract_address,
                    ERC721Component::Event::Transfer(
                        ERC721Component::Transfer { from: Zero::zero(), to: BOB, token_id: 14 },
                    ),
                ),
                (
                    ethrx.contract_address,
                    ERC721Component::Event::Transfer(
                        ERC721Component::Transfer { from: Zero::zero(), to: BOB, token_id: 15 },
                    ),
                ),
                (
                    ethrx.contract_address,
                    ERC721Component::Event::Transfer(
                        ERC721Component::Transfer { from: Zero::zero(), to: BOB, token_id: 16 },
                    ),
                ),
            ],
        );
}

#[test]
fn test_mint_over_supply() {
    let (ethrx, erc20) = setup();

    let total_supply_before = ethrx.total_supply();
    let owner_balance_before = erc20.balance_of(OWNER);
    let bystander_balance_before = erc20.balance_of(BYSTANDER);

    // Mint more than max supply (as bystander)
    let mut spy = spy_events();
    ethrx.mint_batch_star(array![ALICE, BOB], array![ethrx.max_supply(), ethrx.max_supply()]);

    let total_supply_after = ethrx.total_supply();
    let owner_balance_after = erc20.balance_of(OWNER);
    let bystander_balance_after = erc20.balance_of(BYSTANDER);

    assert!(
        total_supply_after == ethrx.max_supply(),
        "total supply should only increase up to max supply",
    );

    assert!(
        owner_balance_after == owner_balance_before
            + MINT_PRICE * (ethrx.max_supply() - total_supply_before),
        "owner should receive the mint price only for tokens minted up to max supply",
    );

    assert!(
        bystander_balance_after == bystander_balance_before
            - MINT_PRICE * (ethrx.max_supply() - total_supply_before),
        "Bystander's balance should decrease only by the mint price for tokens minted up to max supply",
    );

    spy
        .assert_emitted(
            @array![
                (
                    erc20.contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: BYSTANDER,
                            to: OWNER,
                            value: MINT_PRICE * (ethrx.max_supply() - total_supply_before),
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[feature("safe_dispatcher")]
fn test_minting_no_allownace_or_funds() {
    let (ethrx, erc20) = setup();
    let ethrx = IEthrxSafeDispatcher { contract_address: ethrx.contract_address };

    // No allowance
    start_cheat_caller_address(ethrx.contract_address, BYSTANDER);
    let result = ethrx.mint(array![1, 2], array![ALICE, BOB]);
    assert!(result.is_err(), "minting without allowance should fail");
    assert!(
        result.unwrap_err() == array!['ERC20: insufficient allowance'], "error message mismatch",
    );
    stop_cheat_caller_address(ethrx.contract_address);

    // No funds
    start_cheat_caller_address(erc20.contract_address, BYSTANDER);
    erc20.transfer(ALICE, erc20.balance_of(BYSTANDER)); // empty BYSTANDER's balance
    erc20.approve(ethrx.contract_address, MINT_PRICE * 10); // set allowance
    stop_cheat_caller_address(erc20.contract_address);

    start_cheat_caller_address(ethrx.contract_address, BYSTANDER);
    let result = ethrx.mint(array![1, 2], array![ALICE, BOB]);
    assert!(result.is_err(), "minting without funds should fail");
    assert!(result.unwrap_err() == array!['ERC20: insufficient balance'], "error message mismatch");
}

fn build_engraving(tag: felt252, data: ByteArray) -> Engraving {
    Engraving { tag, data: data.to_bytes() }
}

#[test]
fn test_engraving() {
    let (ethrx, _) = setup();
    let new_artifact = Artifact {
        collection: array![
            ethrx.build_engraving('TITLE', "a"), ethrx.build_engraving('MESSAGE', "b"),
            ethrx.build_engraving('URL', "x"), ethrx.build_engraving('X_HANDLE', "c"),
            ethrx.build_engraving('GITHUB_HANDLE', "d"),
        ],
    };
    ethrx.mint_star(ALICE);

    let mut spy = spy_events();
    ethrx.engrave_star(12, new_artifact.clone());

    let artifact_id = ethrx.token_id_to_artifact_id(12);
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'TITLE') == 1, "TITLE nonce should be 1");
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'MESSAGE') == 1, "MESSAGE nonce should be 1");
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'URL') == 1, "URL nonce should be 1");
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'X_HANDLE') == 1, "X_HANDLE nonce should be 1");
    assert!(
        ethrx.artifact_tag_nonce(artifact_id, 'GITHUB_HANDLE') == 1,
        "GITHUB_HANDLE nonce should be 1",
    );
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'RANDOM') == 0, "RANDOM nonce should be 0");
    assert!(ethrx.get_artifact(12) == new_artifact, "artifact data mismatch");
    // Assert engraving events
    spy
        .assert_emitted(
            @array![
                (
                    ethrx.contract_address,
                    Ethrx::Event::ArtifactEngraved(
                        Ethrx::ArtifactEngraved {
                            token_id: 12,
                            old_engraving: ethrx.build_engraving('X_HANDLE', ""),
                            new_engraving: ethrx.build_engraving('X_HANDLE', "c"),
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_engraving_wipe() {
    let (ethrx, _) = setup();
    ethrx.mint_star(ALICE);

    let new_artifact = Artifact {
        collection: array![
            ethrx.build_engraving('TITLE', "a"), ethrx.build_engraving('MESSAGE', "b"),
            ethrx.build_engraving('URL', "x"), ethrx.build_engraving('X_HANDLE', "c"),
            ethrx.build_engraving('GITHUB_HANDLE', "d"),
        ],
    };

    ethrx.engrave_star(12, new_artifact.clone());
    assert!(ethrx.token_id_to_artifact_id(12).into() == 12, "token artifact id should be 12");

    ethrx.transfer_star(ALICE, BOB, 12);
    assert!(
        ethrx.token_id_to_artifact_id(12).into() == 13,
        "token artifact id should be set to 13 after transfer",
    );

    let artifact_id = ethrx.token_id_to_artifact_id(12);
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'TITLE') == 0, "TITLE nonce should be 0");
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'MESSAGE') == 0, "MESSAGE nonce should be 0");
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'URL') == 0, "URL nonce should be 0");
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'X_HANDLE') == 0, "X_HANDLE nonce should be 0");
    assert!(
        ethrx.artifact_tag_nonce(artifact_id, 'GITHUB_HANDLE') == 0,
        "GITHUB_HANDLE nonce should be 0",
    );
    assert!(
        ethrx.artifact_tag_nonce(artifact_id, 'RANDOM') == 0, "RANDOM nonce should
        be 0",
    );
    let empty_artifact = Artifact {
        collection: array![
            ethrx.build_engraving('TITLE', ""), ethrx.build_engraving('MESSAGE', ""),
            ethrx.build_engraving('URL', ""), ethrx.build_engraving('X_HANDLE', ""),
            ethrx.build_engraving('GITHUB_HANDLE', ""),
        ],
    };
    assert!(ethrx.get_artifact(12) == empty_artifact, "engraving data mismatch");
}

#[test]
fn test_engraving_keep() {
    let (ethrx, _) = setup();
    ethrx.mint_star(ALICE);

    let new_artifact = Artifact {
        collection: array![
            ethrx.build_engraving('TITLE', "a"), ethrx.build_engraving('MESSAGE', "b"),
            ethrx.build_engraving('URL', "x"), ethrx.build_engraving('X_HANDLE', "c"),
            ethrx.build_engraving('GITHUB_HANDLE', "d"),
        ],
    };

    ethrx.engrave_star(12, new_artifact.clone());

    ethrx.transfer_with_engraving_star(ALICE, BOB, 12);

    let artifact_id = ethrx.token_id_to_artifact_id(12);
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'TITLE') == 1, "TITLE nonce should be 1");
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'MESSAGE') == 1, "MESSAGE nonce should be 1");
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'URL') == 1, "URL nonce should be 1");
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'X_HANDLE') == 1, "X_HANDLE nonce should be 1");
    assert!(
        ethrx.artifact_tag_nonce(artifact_id, 'GITHUB_HANDLE') == 1,
        "GITHUB_HANDLE nonce should be 1",
    );
    assert!(ethrx.artifact_tag_nonce(artifact_id, 'RANDOM') == 0, "RANDOM nonce should be 0");
    assert!(ethrx.get_artifact(12) == new_artifact, "engraving data mismatch");
}

fn bytes_array_builder(strings: Array<ByteArray>) -> Array<Bytes> {
    strings.into_iter().map(|s| Into::<ByteArray, Bytes>::into(s)).collect()
}

trait ToBytes<T> {
    fn to_bytes(self: T) -> Bytes;
}


impl BAToBytesImpl of ToBytes<ByteArray> {
    fn to_bytes(self: ByteArray) -> Bytes {
        Into::<ByteArray, Bytes>::into(self)
    }
}

#[test]
fn test_set_contract_uri_owner() {
    let (ethrx, _) = setup();

    let new_contract_uri = "https://example.com/new-contract";
    let initial_contract_uri = ethrx.contract_uri();

    // Owner should be able to set contract URI
    start_cheat_caller_address(ethrx.contract_address, OWNER);
    ethrx.set_contract_uri(new_contract_uri.clone());
    stop_cheat_caller_address(ethrx.contract_address);

    assert!(ethrx.contract_uri() == new_contract_uri, "contract URI should be updated");
    assert!(
        ethrx.contract_uri() != initial_contract_uri,
        "contract URI should be different from initial value",
    );
}

#[test]
#[should_panic]
fn test_set_contract_uri_non_owner() {
    let (ethrx, _) = setup();

    let new_contract_uri = "https://example.com/new-contract.json";

    // Non-owner should not be able to set contract URI - should panic
    start_cheat_caller_address(ethrx.contract_address, ALICE);
    ethrx.set_contract_uri(new_contract_uri);
    stop_cheat_caller_address(ethrx.contract_address);
}

/// ERC721Enumerable Tests ///

#[test]
fn test_enumerable_initial_state() {
    let (ethrx, _) = setup();

    // After constructor, 11 tokens should be minted to OWNER
    assert!(ethrx.total_supply() == 11, "initial total supply should be 11");
    assert!(ethrx.balance_of(OWNER) == 11, "OWNER should have 11 tokens initially");

    // Test token_by_index for all initial tokens
    for i in 0..11_usize {
        let token_id = ethrx.token_by_index(i);
        assert!(token_id == (i + 1).into(), "token_by_index({i}) should return {}", i + 1);
        assert!(ethrx.owner_of(token_id) == OWNER, "token {token_id} should be owned by OWNER");
    }

    // Test token_of_owner_by_index for OWNER
    for i in 0..11_usize {
        let token_id = ethrx.token_of_owner_by_index(OWNER, i);
        assert!(
            token_id == (i + 1).into(),
            "token_of_owner_by_index(OWNER, {i}) should return {}",
            i + 1,
        );
    }
}

#[test]
fn test_enumerable_after_mint() {
    let (ethrx, _) = setup();

    // Mint tokens to ALICE and BOB
    ethrx.mint_batch_star(array![ALICE, BOB], array![2, 3]);

    assert!(ethrx.total_supply() == 16, "total supply should be 16 after minting 5 tokens");
    assert!(ethrx.balance_of(ALICE) == 2, "ALICE should have 2 tokens");
    assert!(ethrx.balance_of(BOB) == 3, "BOB should have 3 tokens");
    assert!(ethrx.balance_of(OWNER) == 11, "OWNER should still have 11 tokens");

    // Test token_by_index for all tokens (should be 1-16)
    for i in 0..16_usize {
        let token_id = ethrx.token_by_index(i);
        assert!(token_id == (i + 1).into(), "token_by_index({i}) should return {}", i + 1);
    }

    // Test token_of_owner_by_index for ALICE (tokens 12, 13)
    assert!(ethrx.token_of_owner_by_index(ALICE, 0) == 12, "ALICE's first token should be 12");
    assert!(ethrx.token_of_owner_by_index(ALICE, 1) == 13, "ALICE's second token should be 13");

    // Test token_of_owner_by_index for BOB (tokens 14, 15, 16)
    assert!(ethrx.token_of_owner_by_index(BOB, 0) == 14, "BOB's first token should be 14");
    assert!(ethrx.token_of_owner_by_index(BOB, 1) == 15, "BOB's second token should be 15");
    assert!(ethrx.token_of_owner_by_index(BOB, 2) == 16, "BOB's third token should be 16");

    // Test token_of_owner_by_index for OWNER (tokens 1-11)
    for i in 0..11_usize {
        let token_id = ethrx.token_of_owner_by_index(OWNER, i);
        assert!(token_id == (i + 1).into(), "OWNER's token at index {i} should be {}", i + 1);
    }
}

#[test]
fn test_enumerable_after_transfer() {
    let (ethrx, _) = setup();

    // Mint a token to ALICE
    ethrx.mint_star(ALICE);
    assert!(ethrx.balance_of(ALICE) == 1, "ALICE should have 1 token");
    assert!(ethrx.token_of_owner_by_index(ALICE, 0) == 12, "ALICE's token should be 12");

    // Transfer token 12 from ALICE to BOB
    ethrx.transfer_star(ALICE, BOB, 12);

    assert!(ethrx.balance_of(ALICE) == 0, "ALICE should have 0 tokens after transfer");
    assert!(ethrx.balance_of(BOB) == 1, "BOB should have 1 token after transfer");
    assert!(ethrx.owner_of(12) == BOB, "token 12 should be owned by BOB");

    // ALICE should have no tokens
    // BOB should have token 12 at index 0
    assert!(ethrx.token_of_owner_by_index(BOB, 0) == 12, "BOB's first token should be 12");

    // token_by_index should still work correctly
    assert!(ethrx.token_by_index(11) == 12, "token_by_index(11) should return 12");
}

#[test]
fn test_enumerable_multiple_transfers() {
    let (ethrx, _) = setup();

    // Mint tokens to ALICE
    ethrx.mint_batch_star(array![ALICE], array![5]);
    assert!(ethrx.balance_of(ALICE) == 5, "ALICE should have 5 tokens");

    // Transfer tokens 12, 13, 14 from ALICE to BOB
    ethrx.transfer_star(ALICE, BOB, 12);
    ethrx.transfer_star(ALICE, BOB, 13);
    ethrx.transfer_star(ALICE, BOB, 14);

    assert!(ethrx.balance_of(ALICE) == 2, "ALICE should have 2 tokens after transfers");
    assert!(ethrx.balance_of(BOB) == 3, "BOB should have 3 tokens after transfers");

    // ALICE should have tokens 15, 16 (pop and swapped so order looks weird)
    assert!(
        ethrx.token_of_owner_by_index(ALICE, 0) == 16,
        "ALICE's first token should be 15 but is {}",
        ethrx.token_of_owner_by_index(ALICE, 0),
    );
    assert!(ethrx.token_of_owner_by_index(ALICE, 1) == 15, "ALICE's second token should be 16");

    // BOB should have tokens 12, 13, 14
    assert!(ethrx.token_of_owner_by_index(BOB, 0) == 12, "BOB's first token should be 12");
    assert!(ethrx.token_of_owner_by_index(BOB, 1) == 13, "BOB's second token should be 13");
    assert!(ethrx.token_of_owner_by_index(BOB, 2) == 14, "BOB's third token should be 14");
}

#[test]
fn test_enumerable_transfer_back() {
    let (ethrx, _) = setup();

    // Mint token to ALICE
    ethrx.mint_star(ALICE);
    assert!(ethrx.token_of_owner_by_index(ALICE, 0) == 12, "ALICE should have token 12");

    // Transfer from ALICE to BOB
    ethrx.transfer_star(ALICE, BOB, 12);
    assert!(ethrx.balance_of(ALICE) == 0, "ALICE should have 0 tokens");
    assert!(ethrx.balance_of(BOB) == 1, "BOB should have 1 token");
    assert!(ethrx.token_of_owner_by_index(BOB, 0) == 12, "BOB should have token 12");

    // Transfer back from BOB to ALICE
    ethrx.transfer_star(BOB, ALICE, 12);
    assert!(ethrx.balance_of(ALICE) == 1, "ALICE should have 1 token");
    assert!(ethrx.balance_of(BOB) == 0, "BOB should have 0 tokens");
    assert!(ethrx.token_of_owner_by_index(ALICE, 0) == 12, "ALICE should have token 12 again");
}

#[test]
#[should_panic]
fn test_enumerable_token_by_index_out_of_bounds() {
    let (ethrx, _) = setup();

    // Should panic when accessing index beyond total_supply
    let total = ethrx.total_supply();
    ethrx.token_by_index(total.try_into().unwrap());
}

#[test]
#[should_panic]
fn test_enumerable_token_of_owner_by_index_out_of_bounds() {
    let (ethrx, _) = setup();

    // ALICE has no tokens initially, should panic
    ethrx.token_of_owner_by_index(ALICE, 0);
}

#[test]
#[should_panic]
fn test_enumerable_token_of_owner_by_index_out_of_bounds_after_transfer() {
    let (ethrx, _) = setup();

    // Mint token to ALICE
    ethrx.mint_star(ALICE);
    assert!(ethrx.balance_of(ALICE) == 1, "ALICE should have 1 token");

    // Transfer token away
    ethrx.transfer_star(ALICE, BOB, 12);
    assert!(ethrx.balance_of(ALICE) == 0, "ALICE should have 0 tokens");

    // Should panic when accessing ALICE's tokens
    ethrx.token_of_owner_by_index(ALICE, 0);
}

#[test]
fn test_enumerable_consistency_after_batch_mint() {
    let (ethrx, _) = setup();

    // Mint multiple tokens to different owners
    ethrx.mint_batch_star(array![ALICE, BOB, ALICE], array![3, 2, 1]);

    assert!(ethrx.total_supply() == 17, "total supply should be 17");
    assert!(ethrx.balance_of(ALICE) == 4, "ALICE should have 4 tokens");
    assert!(ethrx.balance_of(BOB) == 2, "BOB should have 2 tokens");

    // Verify all tokens are enumerable
    for i in 0..17_usize {
        let token_id = ethrx.token_by_index(i);
        assert!(token_id == (i + 1).into(), "token_by_index({i}) should return {}", i + 1);
    }

    // ALICE receives tokens in order: 12, 13, 14, then 17
    // So ALICE should have [12, 13, 14, 17] in that order (no transfers yet)
    let alice_tokens = array![12, 13, 14, 17];
    for i in 0..4_usize {
        let token_id = ethrx.token_of_owner_by_index(ALICE, i);
        assert!(
            token_id == (*alice_tokens.at(i.into())).into(),
            "ALICE's token at index {i} should be {}",
            *alice_tokens.at(i),
        );
    }

    // Verify BOB's tokens (15, 16)
    assert!(ethrx.token_of_owner_by_index(BOB, 0) == 15, "BOB's first token should be 15");
    assert!(ethrx.token_of_owner_by_index(BOB, 1) == 16, "BOB's second token should be 16");
}

#[test]
fn test_enumerable_with_transfer_and_save_artifact() {
    let (ethrx, _) = setup();

    // Mint multiple tokens to ALICE
    ethrx.mint_batch_star(array![ALICE], array![5]);
    assert!(ethrx.balance_of(ALICE) == 5, "ALICE should have 5 tokens");
    assert!(ethrx.total_supply() == 16, "total supply should be 16");

    // Verify ALICE's tokens before transfer (12, 13, 14, 15, 16)
    for i in 0..5_usize {
        let token_id = ethrx.token_of_owner_by_index(ALICE, i);
        assert!(token_id == (12 + i).into(), "ALICE's token at index {i} should be {}", 12 + i);
    }

    // Transfer tokens 12, 13, 14 with artifact saving
    ethrx.transfer_with_engraving_star(ALICE, BOB, 12);
    ethrx.transfer_with_engraving_star(ALICE, BOB, 13);
    ethrx.transfer_with_engraving_star(ALICE, BOB, 14);

    // Verify balances after transfer
    assert!(ethrx.balance_of(ALICE) == 2, "ALICE should have 2 tokens after transfer");
    assert!(ethrx.balance_of(BOB) == 3, "BOB should have 3 tokens after transfer");
    assert!(ethrx.total_supply() == 16, "total supply should remain 16");

    // ALICE originally had [12, 13, 14, 15, 16]
    // Transfer 12 (index 0): swap with 16 → [16, 13, 14, 15]
    // Transfer 13 (index 1): swap with 15 → [16, 15, 14]
    // Transfer 14 (index 2): swap with 14 (last) → [16, 15]
    // So ALICE should have [16, 15] in that order
    assert!(ethrx.token_of_owner_by_index(ALICE, 0) == 16, "ALICE's first token should be 16");
    assert!(ethrx.token_of_owner_by_index(ALICE, 1) == 15, "ALICE's second token should be 15");

    // BOB receives tokens in order: [12, 13, 14]
    assert!(ethrx.token_of_owner_by_index(BOB, 0) == 12, "BOB's first token should be 12");
    assert!(ethrx.token_of_owner_by_index(BOB, 1) == 13, "BOB's second token should be 13");
    assert!(ethrx.token_of_owner_by_index(BOB, 2) == 14, "BOB's third token should be 14");

    // Verify token_by_index still works correctly for all tokens
    for i in 0..16_usize {
        let token_id = ethrx.token_by_index(i);
        assert!(token_id == (i + 1).into(), "token_by_index({i}) should return {}", i + 1);
    }

    // Verify owners are correct
    assert!(ethrx.owner_of(12) == BOB, "token 12 should be owned by BOB");
    assert!(ethrx.owner_of(13) == BOB, "token 13 should be owned by BOB");
    assert!(ethrx.owner_of(14) == BOB, "token 14 should be owned by BOB");
    assert!(ethrx.owner_of(15) == ALICE, "token 15 should be owned by ALICE");
    assert!(ethrx.owner_of(16) == ALICE, "token 16 should be owned by ALICE");
}

#[test]
fn test_enumerable_batch_transfer_and_save_artifact() {
    let (ethrx, _) = setup();

    // Mint tokens to ALICE and BOB
    ethrx.mint_batch_star(array![ALICE, BOB], array![4, 3]);
    assert!(ethrx.total_supply() == 18, "total supply should be 18");
    assert!(ethrx.balance_of(ALICE) == 4, "ALICE should have 4 tokens");
    assert!(ethrx.balance_of(BOB) == 3, "BOB should have 3 tokens");

    // Transfer multiple tokens from ALICE to BOB using batch transfer_and_save_artifact
    start_cheat_caller_address(ethrx.contract_address, ALICE);
    ethrx.transfer_batch_with_engraving(array![ALICE, ALICE], array![BOB, BOB], array![12, 13]);
    stop_cheat_caller_address(ethrx.contract_address);

    // Verify enumerable state after batch transfer
    assert!(ethrx.balance_of(ALICE) == 2, "ALICE should have 2 tokens after batch transfer");
    assert!(ethrx.balance_of(BOB) == 5, "BOB should have 5 tokens after batch transfer");
    assert!(ethrx.total_supply() == 18, "total supply should remain 18");

    // ALICE originally had [12, 13, 14, 15]
    // Transfer 12 (index 0): swap with 15 → [15, 13, 14]
    // Transfer 13 (index 1): swap with 14 → [15, 14]
    // So ALICE should have [15, 14] in that order
    assert!(ethrx.token_of_owner_by_index(ALICE, 0) == 15, "ALICE's first token should be 15");
    assert!(ethrx.token_of_owner_by_index(ALICE, 1) == 14, "ALICE's second token should be 14");

    // BOB originally had [16, 17, 18], then receives 12, 13 in order
    // So BOB should have [16, 17, 18, 12, 13] in that order
    let bob_tokens = array![16, 17, 18, 12, 13];
    for i in 0..5_usize {
        let token_id = ethrx.token_of_owner_by_index(BOB, i);
        assert!(
            token_id == (*bob_tokens.at(i)).into(),
            "BOB's token at index {i} should be {}",
            *bob_tokens.at(i),
        );
    }

    // Verify all tokens are still enumerable via token_by_index
    for i in 0..18_usize {
        let token_id = ethrx.token_by_index(i);
        assert!(token_id == (i + 1).into(), "token_by_index({i}) should return {}", i + 1);
    }
}

#[test]
fn test_enumerable_transfer_and_save_artifact_with_engravings() {
    let (ethrx, _) = setup();

    // Mint token to ALICE
    ethrx.mint_star(ALICE);
    assert!(ethrx.balance_of(ALICE) == 1, "ALICE should have 1 token");

    // Engrave the token with some data
    // Note: get_artifacts returns all official tags in the order they were registered
    // We engrave with all tags to ensure proper comparison
    let new_artifact = Artifact {
        collection: array![
            ethrx.build_engraving('TITLE', "Test Title"),
            ethrx.build_engraving('MESSAGE', "Test Message"),
            ethrx.build_engraving('GITHUB_HANDLE', "test-github"),
        ],
    };
    ethrx.engrave_star(12, new_artifact.clone());

    // Verify artifact exists before transfer
    let retrieved_artifact = ethrx.get_artifact(12);
    assert!(retrieved_artifact == new_artifact, "artifact should exist before transfer");

    // Transfer with artifact saving
    ethrx.transfer_with_engraving_star(ALICE, BOB, 12);

    // Verify enumerable state
    assert!(ethrx.balance_of(ALICE) == 0, "ALICE should have 0 tokens");
    assert!(ethrx.balance_of(BOB) == 1, "BOB should have 1 token");
    assert!(ethrx.token_of_owner_by_index(BOB, 0) == 12, "BOB should have token 12");
    assert!(ethrx.token_by_index(11) == 12, "token_by_index(11) should return 12");

    // Verify artifact is preserved after transfer
    let retrieved_artifact_after = ethrx.get_artifact(12);
    assert!(
        retrieved_artifact_after == new_artifact, "artifact should be preserved after transfer",
    );
}

#[test]
fn test_enumerable_transfer_and_save_artifact_partial_engravings() {
    let (ethrx, _) = setup();

    // Mint token to ALICE
    ethrx.mint_star(ALICE);
    assert!(ethrx.balance_of(ALICE) == 1, "ALICE should have 1 token");

    // Engrave only TITLE and MESSAGE (partial engraving)
    let partial_artifact = Artifact {
        collection: array![
            ethrx.build_engraving('TITLE', "Partial Title"),
            ethrx.build_engraving('MESSAGE', "Partial Message"),
        ],
    };
    ethrx.engrave_star(12, partial_artifact);

    // get_artifacts returns all official tags, so unengraved tags will have empty data
    let retrieved = ethrx.get_artifact(12);
    // Verify that TITLE and MESSAGE are set
    let mut found_title = false;
    let mut found_message = false;
    for engraving in retrieved.collection {
        if engraving.tag == 'TITLE' {
            let data_ba: ByteArray = engraving.data.clone().into();
            assert!(data_ba == "Partial Title", "TITLE should be preserved");
            found_title = true;
        }
        if engraving.tag == 'MESSAGE' {
            let data_ba: ByteArray = engraving.data.clone().into();
            assert!(data_ba == "Partial Message", "MESSAGE should be preserved");
            found_message = true;
        }
    }
    assert!(found_title, "TITLE should be in artifact");
    assert!(found_message, "MESSAGE should be in artifact");

    // Transfer with artifact saving
    ethrx.transfer_with_engraving_star(ALICE, BOB, 12);

    // Verify enumerable state
    assert!(ethrx.balance_of(ALICE) == 0, "ALICE should have 0 tokens");
    assert!(ethrx.balance_of(BOB) == 1, "BOB should have 1 token");

    // Verify artifact is preserved after transfer
    let retrieved_after = ethrx.get_artifact(12);
    let mut found_title_after = false;
    let mut found_message_after = false;
    for engraving in retrieved_after.collection {
        if engraving.tag == 'TITLE' {
            let data_ba: ByteArray = engraving.data.clone().into();
            assert!(data_ba == "Partial Title", "TITLE should be preserved after transfer");
            found_title_after = true;
        }
        if engraving.tag == 'MESSAGE' {
            let data_ba: ByteArray = engraving.data.clone().into();
            assert!(data_ba == "Partial Message", "MESSAGE should be preserved after transfer");
            found_message_after = true;
        }
    }
    assert!(found_title_after, "TITLE should be in artifact after transfer");
    assert!(found_message_after, "MESSAGE should be in artifact after transfer");
}

#[test]
fn test_enumerable_transfer_and_save_artifact_with_full_engravings() {
    let (ethrx, _) = setup();

    // Mint token to ALICE
    ethrx.mint_star(ALICE);
    assert!(ethrx.balance_of(ALICE) == 1, "ALICE should have 1 token");

    // Engrave with all official tags
    let full_artifact = Artifact {
        collection: array![
            ethrx.build_engraving('TITLE', "Full Title"),
            ethrx.build_engraving('MESSAGE', "Full Message"),
            ethrx.build_engraving('URL', "https://example.com"),
            ethrx.build_engraving('X_HANDLE', "@test"),
            ethrx.build_engraving('GITHUB_HANDLE', "testuser"),
        ],
    };
    ethrx.engrave_star(12, full_artifact.clone());

    // Verify artifact exists before transfer
    assert!(ethrx.get_artifact(12) == full_artifact, "artifact should exist before transfer");

    // Transfer with artifact saving
    ethrx.transfer_with_engraving_star(ALICE, BOB, 12);

    // Verify enumerable state
    assert!(ethrx.balance_of(ALICE) == 0, "ALICE should have 0 tokens");
    assert!(ethrx.balance_of(BOB) == 1, "BOB should have 1 token");
    assert!(ethrx.token_of_owner_by_index(BOB, 0) == 12, "BOB should have token 12");
    assert!(ethrx.token_by_index(11) == 12, "token_by_index(11) should return 12");

    // Verify artifact is preserved after transfer
    assert!(ethrx.get_artifact(12) == full_artifact, "artifact should be preserved after transfer");
}

#[test]
fn test_enumerable_transfer_and_save_artifact_multiple_engravings() {
    let (ethrx, _) = setup();

    // Mint tokens to ALICE
    ethrx.mint_batch_star(array![ALICE], array![3]);
    assert!(ethrx.balance_of(ALICE) == 3, "ALICE should have 3 tokens");

    // Engrave each token with different data
    let artifact1 = Artifact {
        collection: array![
            ethrx.build_engraving('TITLE', "Token 12"),
            ethrx.build_engraving('MESSAGE', "Message 12"), ethrx.build_engraving('URL', ""),
            ethrx.build_engraving('X_HANDLE', ""), ethrx.build_engraving('GITHUB_HANDLE', ""),
        ],
    };
    let artifact2 = Artifact {
        collection: array![
            ethrx.build_engraving('TITLE', "Token 13"),
            ethrx.build_engraving('MESSAGE', "Message 13"), ethrx.build_engraving('URL', ""),
            ethrx.build_engraving('X_HANDLE', ""), ethrx.build_engraving('GITHUB_HANDLE', ""),
        ],
    };
    let artifact3 = Artifact {
        collection: array![
            ethrx.build_engraving('TITLE', "Token 14"),
            ethrx.build_engraving('MESSAGE', "Message 14"), ethrx.build_engraving('URL', ""),
            ethrx.build_engraving('X_HANDLE', ""), ethrx.build_engraving('GITHUB_HANDLE', ""),
        ],
    };

    ethrx.engrave_star(12, artifact1.clone());
    ethrx.engrave_star(13, artifact2.clone());
    ethrx.engrave_star(14, artifact3.clone());

    // Transfer all tokens with artifact saving
    ethrx.transfer_with_engraving_star(ALICE, BOB, 12);
    ethrx.transfer_with_engraving_star(ALICE, BOB, 13);
    ethrx.transfer_with_engraving_star(ALICE, BOB, 14);

    // Verify enumerable state
    assert!(ethrx.balance_of(ALICE) == 0, "ALICE should have 0 tokens");
    assert!(ethrx.balance_of(BOB) == 3, "BOB should have 3 tokens");
    assert!(ethrx.token_of_owner_by_index(BOB, 0) == 12, "BOB's first token should be 12");
    assert!(ethrx.token_of_owner_by_index(BOB, 1) == 13, "BOB's second token should be 13");
    assert!(ethrx.token_of_owner_by_index(BOB, 2) == 14, "BOB's third token should be 14");

    // Verify all artifacts are preserved
    assert!(ethrx.get_artifact(12) == artifact1, "artifact 1 should be preserved");
    assert!(ethrx.get_artifact(13) == artifact2, "artifact 2 should be preserved");
    assert!(ethrx.get_artifact(14) == artifact3, "artifact 3 should be preserved");
}

#[test]
fn test_enumerable_transfer_and_save_artifact_back_and_forth() {
    let (ethrx, _) = setup();

    // Mint tokens to ALICE
    ethrx.mint_batch_star(array![ALICE], array![3]);
    assert!(ethrx.balance_of(ALICE) == 3, "ALICE should have 3 tokens");

    // ALICE originally had [12, 13, 14]
    // Transfer token 12 from ALICE to BOB with artifact saving
    // Transfer 12 (index 0): swap with 14 → [14, 13, 12], remove last → [14, 13]
    ethrx.transfer_with_engraving_star(ALICE, BOB, 12);
    assert!(ethrx.balance_of(ALICE) == 2, "ALICE should have 2 tokens");
    assert!(ethrx.balance_of(BOB) == 1, "BOB should have 1 token");
    assert!(ethrx.token_of_owner_by_index(ALICE, 0) == 14, "ALICE's first token should be 14");
    assert!(ethrx.token_of_owner_by_index(ALICE, 1) == 13, "ALICE's second token should be 13");
    assert!(ethrx.token_of_owner_by_index(BOB, 0) == 12, "BOB should have token 12");

    // Transfer token 12 back from BOB to ALICE with artifact saving
    // BOB has [12] (index 0, which is last), so just remove → []
    // ALICE receives 12 at the end → [14, 13, 12]
    ethrx.transfer_with_engraving_star(BOB, ALICE, 12);
    assert!(ethrx.balance_of(ALICE) == 3, "ALICE should have 3 tokens again");
    assert!(ethrx.balance_of(BOB) == 0, "BOB should have 0 tokens");
    assert!(ethrx.token_of_owner_by_index(ALICE, 0) == 14, "ALICE's first token should be 14");
    assert!(ethrx.token_of_owner_by_index(ALICE, 1) == 13, "ALICE's second token should be 13");
    assert!(ethrx.token_of_owner_by_index(ALICE, 2) == 12, "ALICE's third token should be 12");

    // Verify token_by_index still works
    assert!(ethrx.token_by_index(11) == 12, "token_by_index(11) should return 12");
    assert!(ethrx.token_by_index(12) == 13, "token_by_index(12) should return 13");
    assert!(ethrx.token_by_index(13) == 14, "token_by_index(13) should return 14");
}

#[test]
fn test_enumerable_at_max_supply() {
    let (ethrx, _) = setup();

    let initial_supply = ethrx.total_supply();
    let remaining = ethrx.max_supply() - initial_supply;

    // Mint up to max supply
    ethrx.mint_batch_star(array![ALICE], array![remaining]);

    assert!(ethrx.total_supply() == ethrx.max_supply(), "total supply should equal max supply");

    // Verify all tokens are enumerable (max_supply is 111)
    for i in 0..111_usize {
        let token_id = ethrx.token_by_index(i);
        assert!(token_id == (i + 1).into(), "token_by_index({i}) should return {}", i + 1);
    }

    // Verify ALICE has the newly minted tokens (100 tokens)
    let alice_balance = ethrx.balance_of(ALICE);
    assert!(alice_balance == remaining, "ALICE should have all newly minted tokens");

    // Verify ALICE's tokens are correctly indexed (tokens 12-111)
    for i in 0..100_usize {
        let token_id = ethrx.token_of_owner_by_index(ALICE, i);
        assert!(
            token_id == (initial_supply + i.into() + 1).into(),
            "ALICE's token at index {i} should be {}",
            initial_supply + i.into() + 1,
        );
    }
}

