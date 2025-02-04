const Web3 = require('web3');

// Function to create a Web3 instance using the RPC URL
const createWeb3Instance = (rpcUrl) => {
    return new Web3(new Web3.providers.HttpProvider(rpcUrl));
};

const estimateGasPrice = async (networkName) => {
    const rpcUrl = getRpcUrl(networkName);
    if (!rpcUrl) {
        throw new Error(`RPC URL for ${networkName} not found.`);
    }

    const web3 = createWeb3Instance(rpcUrl);
    let gasPrice = await web3.eth.getGasPrice();
    let gasPriceToNumber = parseInt(gasPrice, 10);

    let percent = 50;
    let number = gasPriceToNumber * (percent / 100);
    let newGasPrice = gasPriceToNumber + number;

    let gasPriceHexa = parseInt(newGasPrice, 10);
    console.log(gasPriceHexa / 1e9);
    return gasPriceHexa;
};

module.exports = {
    estimateGasPrice
};
