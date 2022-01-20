# com-contract-union
Next version of Comunion contract project

# how to start
1. install truffle
    ```
    npm install -g truffle
    ```

2. add a sol in contract dir
3. add it to 2_deploy_contract
    ```
    const Startup = artifacts.require('Startup');


    module.exports = (deployer) => {
      deployer.deploy(Startup);
    };
    ```
4. migrate contract to development
    ```
    yarn dev
    ```

5. migrate contract to goerli
    ```
    yarn goerli
    ```
6. how to test your contract
  -. write your test sol in test dir
  -. the test function name must start with "test"
  -. migrate your contract
  -. run
    ```
    truffle test
    ```

# how to created local environment

1. use npm install remixed tools

    ```
    npm install -g @remix-project/remixd
    ```

2. open remixed page ( http://remix.ethereum.org)

3. start
in your source code, run
    ```
    remixed -s [your source code list] --remix-ide http://remix.ethereum.org
    ```

4. open "https://remix.ethereum.org/#optimize=true&runs=200"
5. click home -> file -> connect to local host;
6. after loading, happy coding
7. if you installed ganache, you can use ganache;
  - npm install -g ganache-cli
  - use ganache, run ganache-cli in your terminal
    ```
      ganache-cli
    ```
  - if you installed ganache by GUI， you can start it directly
8. after deployed contract, please update contract address in contractAddress.json file