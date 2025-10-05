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
    ALICE, BASE_URI, BOB, BYSTANDER, MAX_SUPPLY, MINT_PRICE, NAME, OWNER, SYMBOL, setup,
};
use crate::utils::EthrxFacadeImpl;


#[test]
fn test_ethrx_constructor_args() {
    let (ethrx, erc20) = setup();

    assert!(ethrx.owner() == OWNER, "owner mismatch");
    assert!(ethrx.name() == NAME(), "name mismatch");
    assert!(ethrx.symbol() == SYMBOL(), "symbol mismatch");
    assert!(ethrx.token_uri(1) == format!("{}{}", BASE_URI(), 1), "base uri mismatch");
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

