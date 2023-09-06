## Figuritas.eth
**Go back and play like a child**

Figuritas is an old project, lost in some personal computer migration, now getting an update!

Uses Chainlink VRF2 to randomize figus creation and incentivizes both the creator & users to complete their albums 
On creation of FiguritasCollection will receive:
    - uri
        - name, description, images and more are to be in metadata located here
    - densityCurveFiguritas
        - an array of uint8 stating density of emission for each card (as its index). Preferably reduced to minimum common denominator to reduce contract storage


TODO:
- continue w/TTD
    - fees & withdraw                   <<<
        - differentiate sobres (LINK fees related) with albums (only for protocol) 
    - TradingPit
        - exchange of figus with multiple conditions

    

second test: https://sepolia.etherscan.io/address/0x7d22603C231a747A99B0Cabab6B2E6EaA7D983Ae
    sobres factory: 0xAA36Cf581373e97794f183882A1C9419F3E32485
test token: 0xe203e99c57A7F8913E3E617b279C4d9E0F9f13b2

-----------------------------------------------------------
- VRF v2 (https://docs.chain.link/vrf/v2/subscription)
https://vrf.chain.link/sepolia/4963




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
