const { Account, RpcProvider, json, Contract, ec, constants, num, hash } = require('starknet');
const fs = require('fs');


async function main() {
  const maxQtyGasAuthorized = 180000n;
  const maxPriceAuthorizeForOneGas = 10n ** 15n;
  const provider = new RpcProvider({
    nodeUrl: 'https://starknet-sepolia.public.blastapi.io',
  });

  const lastBlock = await provider.getBlock('latest');
  const keyFilter = [[num.toHex(hash.starknetKeccak('DepositHandled'))]];
  const eventsList = await provider.getEvents({
    address: "0x0594c1582459ea03f77deaf9eb7e3917d6994a03c13405ba42867f83d85f085d",
    from_block: { block_number: 766015 - 10 },
    to_block: { block_number: lastBlock.block_number },
    keys: keyFilter,
    chunk_size: 10,
  });
  console.log(eventsList);

  const privateKey = '0x260d0115277b97215b9645fb0a8028ffc299fc223027742be62b6155aa8e3ac';
  const accountAddress = '0xd5944409b0e99d8671207c1a1f8db223a258f2effa29efdf2cbddf0a85d1b1';

  const account = new Account(provider, accountAddress, privateKey, undefined, constants.TRANSACTION_VERSION.V3);
  console.log(account)

  const erc20_address = '0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d';

  const { abi: testAbi } = await provider.getClassAt(erc20_address);
  if (testAbi === undefined) {
    throw new Error('no abi.');
  }

  const erc20 = new Contract(testAbi, erc20_address, provider);
  erc20.connect(account);
  const tx = await erc20.balance_of("0x00d5944409b0e99d8671207c1a1f8db223a258f2effa29efdf2cbddf0a85d1b1");
  console.log(tx);

  const vault_address = "0x06224ff8cd622bb4e960b2dd59f868e4c85bc6d27b6a2ba5cf22366022cb32c4";
  const { abi: vaultAbi } = await provider.getClassAt(vault_address);
  const vault = new Contract(vaultAbi, vault_address, provider);
  vault.connect(account);

  const tx1 = await erc20.approve("0x06224ff8cd622bb4e960b2dd59f868e4c85bc6d27b6a2ba5cf22366022cb32c4", 1000000000);

  const myCall1 = erc20.populate('approve', [
    "0x06224ff8cd622bb4e960b2dd59f868e4c85bc6d27b6a2ba5cf22366022cb32c4",
    100
  ]);
  const { transaction_hash: txH } = await account.execute(myCall1, {
    version: constants.TRANSACTION_VERSION.V3,
    maxFee: 1e15,
    tip: 1e13,
    paymasterData: [],
    resourceBounds: {
      l1_gas: {
        max_amount: num.toHex(maxQtyGasAuthorized),
        max_price_per_unit: num.toHex(maxPriceAuthorizeForOneGas),
      },
      l2_gas: {
        max_amount: num.toHex(0),
        max_price_per_unit: num.toHex(0),
      },
    },
  });
  console.log("tx: ", txH);
  const txR = await provider.waitForTransaction(txH);
  if (txR.isSuccess()) {
    console.log('Paid fee =', txR.actual_fee);
    console.log("events: ", txR.events);
  }
  const txReceipt = await provider.getTransactionReceipt("0x5fddbd9214389991c02426ecfc7bb3e223918fef4bc182449f2a79f2c28eff8");
  console.log("Finality status:", txReceipt.finality_status);
  console.log("events: ", txReceipt.events);

  //const txReceipt = await provider.waitForTransaction(tx12.transaction_hash);
  if (txReceipt.execution_status === 'SUCCEEDED') {
    for (const event of txReceipt.events) {
      console.log('--- Event ---');
      console.log('From Address:', event.from_address);
      console.log('Keys:', event.keys);
      console.log('Data:', event.data);
    }
  }


  // const myCall2 = vault.populate('deposit', [
  //   100
  // ]);

  // const tx2 = await account.execute(myCall2, {
  //   version: constants.TRANSACTION_VERSION.V3,
  //   maxFee: 1e15,
  //   tip: 1e13,
  //   paymasterData: [],
  //   resourceBounds: {
  //     l1_gas: {
  //       max_amount: num.toHex(maxQtyGasAuthorized),
  //       max_price_per_unit: num.toHex(maxPriceAuthorizeForOneGas),
  //     },
  //     l2_gas: {
  //       max_amount: num.toHex(0),
  //       max_price_per_unit: num.toHex(0),
  //     },
  //   },
  // });
  // console.log("Transfer tx hash:", tx2.transaction_hash);

  // const myCall3 = vault.populate('transferToTreasury', [
  //   10,
  //   "0xb1CF4E0a37138660D0760944229E474c8A7DBC21",
  //   "0x0594c1582459ea03f77deaf9eb7e3917d6994a03c13405ba42867f83d85f085d",
  //   "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d"
  // ]);

  // const tx3 = await account.execute(myCall3, {
  //   version: constants.TRANSACTION_VERSION.V3,
  //   maxFee: 1e15,
  //   tip: 1e13,
  //   paymasterData: [],
  //   resourceBounds: {
  //     l1_gas: {
  //       max_amount: num.toHex(maxQtyGasAuthorized),
  //       max_price_per_unit: num.toHex(maxPriceAuthorizeForOneGas),
  //     },
  //     l2_gas: {
  //       max_amount: num.toHex(0),
  //       max_price_per_unit: num.toHex(0),
  //     },
  //   },
  // });
  // console.log("Transfer tx hash:", tx3.transaction_hash);



}
main();


