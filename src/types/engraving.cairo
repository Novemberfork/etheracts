use alexandria_bytes::Bytes;

/// @dev i.e, 'GITHUB_HANDLE': "0xDegenDeveloper"
#[derive(Drop, Clone, Serde, PartialEq)]
pub struct Engraving {
    pub tag: felt252,
    pub data: Bytes,
}

#[derive(Drop, Clone, Serde, PartialEq)]
pub struct Artifact {
    pub collection: Array<Engraving>,
}

pub mod INITIAL_ENGRAVINGS {
    use super::{Artifact, Engraving};

    const TOTAL: u256 = 11;

    pub fn INITIAL_TAGS() -> Array<felt252> {
        array!['TITLE', 'MESSAGE', 'URL', 'X_HANDLE', 'GITHUB_HANDLE']
    }

    fn URL() -> ByteArray {
        "https://novemberfork.io"
    }
    fn X_HANDLE() -> ByteArray {
        "DegenDeveloper"
    }
    fn GITHUB_HANDLE() -> ByteArray {
        "0xDegenDeveloper"
    }

    pub fn INITIAL_ARTIFACT(token_id: u256) -> Artifact {
        assert!(token_id <= TOTAL, "Token ID out of range");

        let mut title: ByteArray = "";
        let mut message: ByteArray = "";

        if token_id == 1 {
            title = format!("#{token_id} The Southpaw");
            message = "";
        } else if token_id == 2 {
            title = format!("#{token_id} Hello, Milkyway");
            message = "";
        } else if token_id == 3 {
            title = format!("#{token_id} Exoplants");
            message = "";
        } else if token_id == 4 {
            title = format!("#{token_id} Type III Civilizations");
            message = "";
        } else if token_id == 5 {
            title = format!("#{token_id} Primates On A Rock Paying Taxes");
            message = "";
        } else if token_id == 6 {
            title = format!("#{token_id} Stuck In A Matrix");
            message = "";
        } else if token_id == 7 {
            title = format!("#{token_id} Awareness");
            message = "";
        } else if token_id == 8 {
            title = format!("#{token_id} Remembering We'll Never Be Those Kids Again");
            message = "";
        } else if token_id == 9 {
            title = format!("#{token_id} Free The Nip");
            message = "";
        } else if token_id == 10 {
            title = format!("#{token_id} Binary");
            message = "";
        } else {
            title = format!("#{token_id} Flowers for my gf who loves flowers <3");
            message = "";
        }

        Artifact {
            collection: array![
                Engraving { tag: 'TITLE', data: title.into() },
                Engraving { tag: 'MESSAGE', data: message.into() },
                Engraving { tag: 'URL', data: URL().into() },
                Engraving { tag: 'X_HANDLE', data: X_HANDLE().into() },
                Engraving { tag: 'GITHUB_HANDLE', data: GITHUB_HANDLE().into() },
            ],
        }
    }
}
