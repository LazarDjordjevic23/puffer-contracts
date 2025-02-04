// Fetch the network name from the command line argument
const networkName = process.argv[2];
if (!networkName) {
    console.error('Please provide the network name as a command line argument.');
    process.exit(1);
}

const {deployAndSaveImplementation, deployAndSaveProxy, fetchConfig, getRpcUrl} = require('./helper')
const globalSettings = fetchConfig(networkName)
const ethers = require("ethers");
const path = require("path");
const fs = require('fs');

async function main() {

    /**
     * !!!! THIS PART ADJUST ACCORDING TO CONTRACT THAT IS WANTED TO BE DEPLOYED
     *
     *         address _controller,
     *         address initialOwner
     * */
    const contractName = "PufferVaultV3";
    const types = [];
    const values = [];

    let proxyAdminAddress = '0xProxyAdminAddress';
    // Deploy and save
    let implementationAddress = await deployAndSaveImplementation(contractName);
    let proxyAddress = await deployAndSaveProxy(contractName, implementationAddress, proxyAdminAddress, types, values);

    const provider = new ethers.JsonRpcProvider(getRpcUrl(networkName));

    // Create contract instance
    // Load the ABI from the JSON file
    const abiPath = path.join(__dirname, 'mainnet-contracts', 'out', contractName + '.sol', contractName + '.json');
    const contractJson = JSON.parse(fs.readFileSync(abiPath, 'utf-8'));
    const abi = contractJson.abi;
    const contract = new ethers.Contract(proxyAddress, abi, provider);

    await contract.initializeV3()
    const oneEth = ethers.parseEther("1");
    await contract.setMaxGrantAmount(oneEth)

    let specific_recipients = globalSettings["specific_recipients"]
    for (let i = 0; i < specific_recipients.length; i++){
        await contract.addRecipient(specific_recipients[i])
    }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });