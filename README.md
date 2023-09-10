TODO:
- factory interfaces
    - if interfaces of "upgraded" models (Album, Pocket, Prizes) where to change Factory will be unusable 
    - maybe do it upgradeable and call it through a proxy?

- continue w/TTD
    - Improve tests     <

- Min price for packs (token dependent)

Optimizations
    - create & use interfaces in the contracts
    - improve density curve generation
    - TradingPit
        (kind of free interpretation of required vs offered)
            implies a problem storing the multiple Item in a struct

test token: 0xe203e99c57A7F8913E3E617b279C4d9E0F9f13b2

-----------------------------------------------------------
- VRF v2 (https://docs.chain.link/vrf/v2/subscription)
https://vrf.chain.link/sepolia/4963



## Figuritas.eth
**Te cambio esta por esas dos**

Figuritas is an old project, lost in some personal computer migration, now getting an update!

Uses Chainlink VRF2 (upgradeable) to randomize figus creation and incentivizes both the creator & users to complete their albums 
On creation of FiguritasCollection will receive:
    - uri
        - name, description, images and more are to be in metadata located here
    - densityCurveFiguritas
        - an array of uint8 stating density of emission for each card (as its index). Preferably reduced to minimum common denominator to reduce contract storage

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
