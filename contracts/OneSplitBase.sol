pragma solidity ^0.5.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interface/IUniswapFactory.sol";
import "./interface/IKyberNetworkProxy.sol";
import "./interface/IKyberUniswapReserve.sol";
import "./interface/IKyberOasisReserve.sol";
import "./interface/IKyberBancorReserve.sol";
import "./interface/IBancorNetwork.sol";
import "./interface/IBancorContractRegistry.sol";
//import "./interface/IBancorNetworkPathFinder.sol";
import "./interface/IBancorConverterRegistry.sol";
import "./interface/IBancorEtherToken.sol";
import "./interface/IOasisExchange.sol";
import "./interface/IWETH.sol";
import "./interface/ICurve.sol";
import "./interface/IChai.sol";
import "./interface/ICompound.sol";
import "./interface/IAaveToken.sol";
import "./interface/IMooniswap.sol";
import "./interface/IUniswapV2Factory.sol";
import "./interface/IDForceSwap.sol";
import "./interface/IShell.sol";
import "./interface/IMStable.sol";
import "./interface/IBalancerRegistry.sol";
import "./IOneSplit.sol";
import "./UniversalERC20.sol";


contract IOneSplitView is IOneSplitConsts {
    function getExpectedReturn(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    )
        public
        view
        returns(
            uint256 returnAmount,
            uint256[] memory distribution
        );

    function getExpectedReturnWithGas(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags,
        uint256 destTokenEthPriceTimesGasPrice
    )
        public
        view
        returns(
            uint256 returnAmount,
            uint256 estimateGasAmount,
            uint256[] memory distribution
        );
}


library DisableFlags {
    function check(uint256 flags, uint256 flag) internal pure returns(bool) {
        return (flags & flag) != 0;
    }
}


contract OneSplitRoot is IOneSplitView {
    using SafeMath for uint256;
    using DisableFlags for uint256;

    using UniversalERC20 for IERC20;
    using UniversalERC20 for IWETH;
    using UniswapV2ExchangeLib for IUniswapV2Exchange;
    using ChaiHelper for IChai;

    uint256 constant internal DEXES_COUNT = 27;
    IERC20 constant internal ETH_ADDRESS = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    IBancorEtherToken constant internal bancorEtherToken = IBancorEtherToken(0xc0829421C1d260BD3cB3E0F06cfE2D52db2cE315);
    IWETH constant internal weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IChai constant internal chai = IChai(0x06AF07097C9Eeb7fD685c692751D5C66dB49c215);
    IERC20 constant internal dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 constant internal bnt = IERC20(0x1F573D6Fb3F13d689FF844B4cE37794d79a7FF1C);
    IERC20 constant internal usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 constant internal usdt = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 constant internal tusd = IERC20(0x0000000000085d4780B73119b644AE5ecd22b376);
    IERC20 constant internal busd = IERC20(0x4Fabb145d64652a948d72533023f6E7A623C7C53);
    IERC20 constant internal susd = IERC20(0x57Ab1ec28D129707052df4dF418D58a2D46d5f51);
    IERC20 constant internal pax = IERC20(0x8E870D67F660D95d5be530380D0eC0bd388289E1);
    IERC20 constant internal renbtc = IERC20(0xEB4C2781e4ebA804CE9a9803C67d0893436bB27D);
    IERC20 constant internal wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20 constant internal tbtc = IERC20(0x1bBE271d15Bb64dF0bc6CD28Df9Ff322F2eBD847);
    IERC20 constant internal hbtc = IERC20(0x0316EB71485b0Ab14103307bf65a021042c6d380);
    IERC20 constant internal sbtc = IERC20(0xfE18be6b3Bd88A2D2A7f928d00292E7a9963CfC6);

    IKyberNetworkProxy constant internal kyberNetworkProxy = IKyberNetworkProxy(0x818E6FECD516Ecc3849DAf6845e3EC868087B755);
    IUniswapFactory constant internal uniswapFactory = IUniswapFactory(0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95);
    IBancorContractRegistry constant internal bancorContractRegistry = IBancorContractRegistry(0x52Ae12ABe5D8BD778BD5397F99cA900624CfADD4);
    //IBancorNetworkPathFinder constant internal bancorNetworkPathFinder = IBancorNetworkPathFinder(0x6F0cD8C4f6F06eAB664C7E3031909452b4B72861);
    //IBancorConverterRegistry constant internal bancorConverterRegistry = IBancorConverterRegistry(0xf6E2D7F616B67E46D708e4410746E9AAb3a4C518);
    IOasisExchange constant internal oasisExchange = IOasisExchange(0x794e6e91555438aFc3ccF1c5076A74F42133d08D);
    ICurve constant internal curveCompound = ICurve(0xA2B47E3D5c44877cca798226B7B8118F9BFb7A56);
    ICurve constant internal curveUSDT = ICurve(0x52EA46506B9CC5Ef470C5bf89f17Dc28bB35D85C);
    ICurve constant internal curveY = ICurve(0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51);
    ICurve constant internal curveBinance = ICurve(0x79a8C46DeA5aDa233ABaFFD40F3A0A2B1e5A4F27);
    ICurve constant internal curveSynthetix = ICurve(0xA5407eAE9Ba41422680e2e00537571bcC53efBfD);
    ICurve constant internal curvePAX = ICurve(0x06364f10B501e868329afBc005b3492902d6C763);
    ICurve constant internal curveRenBTC = ICurve(0x93054188d876f558f4a66B2EF1d97d16eDf0895B);
    ICurve constant internal curveTBTC = ICurve(0x9726e9314eF1b96E45f40056bEd61A088897313E);
    ICurve constant internal curveSBTC = ICurve(0x7fC77b5c7614E1533320Ea6DDc2Eb61fa00A9714);
    IShell constant internal shell = IShell(0xA8253a440Be331dC4a7395B73948cCa6F19Dc97D);
    IAaveLendingPool constant internal aave = IAaveLendingPool(0x398eC7346DcD622eDc5ae82352F02bE94C62d119);
    ICompound constant internal compound = ICompound(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
    ICompoundEther constant internal cETH = ICompoundEther(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5);
    IMooniswapRegistry constant internal mooniswapRegistry = IMooniswapRegistry(0x7079E8517594e5b21d2B9a0D17cb33F5FE2bca70);
    IUniswapV2Factory constant internal uniswapV2 = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    IDForceSwap constant internal dforceSwap = IDForceSwap(0x03eF3f37856bD08eb47E2dE7ABc4Ddd2c19B60F2);
    IMStable constant internal musd = IMStable(0xe2f2a5C287993345a840Db3B0845fbC70f5935a5);
    IMassetRedemptionValidator constant internal musd_helper = IMassetRedemptionValidator(0x4c5e03065bC52cCe84F3ac94DF14bbAC27eac89b);
    IBalancerRegistry constant internal balancerRegistry = IBalancerRegistry(0x65e67cbc342712DF67494ACEfc06fe951EE93982);

    int256 internal constant VERY_NEGATIVE_VALUE = -1e72;

    function _findBestDistribution(
        uint256 s,                // parts
        int256[][] memory amounts // exchangesReturns
    )
        internal
        pure
        returns(
            int256 returnAmount,
            uint256[] memory distribution
        )
    {
        uint256 n = amounts.length;

        int256[][] memory answer = new int256[][](n); // int[n][s+1]
        uint256[][] memory parent = new uint256[][](n); // int[n][s+1]

        for (uint i = 0; i < n; i++) {
            answer[i] = new int256[](s + 1);
            parent[i] = new uint256[](s + 1);
        }

        for (uint j = 0; j <= s; j++) {
            answer[0][j] = amounts[0][j];
            for (uint i = 1; i < n; i++) {
                answer[i][j] = -1e72;
            }
            parent[0][j] = 0;
        }

        for (uint i = 1; i < n; i++) {
            for (uint j = 0; j <= s; j++) {
                answer[i][j] = answer[i - 1][j];
                parent[i][j] = j;

                for (uint k = 1; k <= j; k++) {
                    if (answer[i - 1][j - k] + amounts[i][k] > answer[i][j]) {
                        answer[i][j] = answer[i - 1][j - k] + amounts[i][k];
                        parent[i][j] = j - k;
                    }
                }
            }
        }

        distribution = new uint256[](DEXES_COUNT);

        uint256 partsLeft = s;
        for (uint curExchange = n - 1; partsLeft > 0; curExchange--) {
            distribution[curExchange] = partsLeft - parent[curExchange][partsLeft];
            partsLeft = parent[curExchange][partsLeft];
        }

        returnAmount = (answer[n - 1][s] == VERY_NEGATIVE_VALUE) ? 0 : answer[n - 1][s];
    }

    function _buildBancorPath(
        IERC20 fromToken,
        IERC20 destToken
    ) internal view returns(address[] memory path) {
        if (fromToken == destToken) {
            return new address[](0);
        }

        if (fromToken.isETH()) {
            fromToken = ETH_ADDRESS;
        }
        if (destToken.isETH()) {
            destToken = ETH_ADDRESS;
        }

        if (fromToken == bnt || destToken == bnt) {
            path = new address[](3);
        } else {
            path = new address[](5);
        }

        address fromConverter;
        address toConverter;

        IBancorConverterRegistry bancorConverterRegistry = IBancorConverterRegistry(bancorContractRegistry.addressOf("BancorConverterRegistry"));

        if (fromToken != bnt) {
            (bool success, bytes memory data) = address(bancorConverterRegistry).staticcall.gas(100000)(abi.encodeWithSelector(
                bancorConverterRegistry.getConvertibleTokenSmartToken.selector,
                fromToken.isETH() ? ETH_ADDRESS : fromToken,
                0
            ));
            if (!success) {
                return new address[](0);
            }

            fromConverter = abi.decode(data, (address));
            if (fromConverter == address(0)) {
                return new address[](0);
            }
        }

        if (destToken != bnt) {
            (bool success, bytes memory data) = address(bancorConverterRegistry).staticcall.gas(100000)(abi.encodeWithSelector(
                bancorConverterRegistry.getConvertibleTokenSmartToken.selector,
                destToken.isETH() ? ETH_ADDRESS : destToken,
                0
            ));
            if (!success) {
                return new address[](0);
            }

            toConverter = abi.decode(data, (address));
            if (toConverter == address(0)) {
                return new address[](0);
            }
        }

        if (destToken == bnt) {
            path[0] = address(fromToken);
            path[1] = fromConverter;
            path[2] = address(bnt);
            return path;
        }

        if (fromToken == bnt) {
            path[0] = address(bnt);
            path[1] = toConverter;
            path[2] = address(destToken);
            return path;
        }

        path[0] = address(fromToken);
        path[1] = fromConverter;
        path[2] = address(bnt);
        path[3] = toConverter;
        path[4] = address(destToken);
        return path;
    }

    function _getCompoundToken(IERC20 token) internal pure returns(ICompoundToken) {
        if (token.isETH()) { // ETH
            return ICompoundToken(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5);
        }
        if (token == IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F)) { // DAI
            return ICompoundToken(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
        }
        if (token == IERC20(0x0D8775F648430679A709E98d2b0Cb6250d2887EF)) { // BAT
            return ICompoundToken(0x6C8c6b02E7b2BE14d4fA6022Dfd6d75921D90E4E);
        }
        if (token == IERC20(0x1985365e9f78359a9B6AD760e32412f4a445E862)) { // REP
            return ICompoundToken(0x158079Ee67Fce2f58472A96584A73C7Ab9AC95c1);
        }
        if (token == IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)) { // USDC
            return ICompoundToken(0x39AA39c021dfbaE8faC545936693aC917d5E7563);
        }
        if (token == IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599)) { // WBTC
            return ICompoundToken(0xC11b1268C1A384e55C48c2391d8d480264A3A7F4);
        }
        if (token == IERC20(0xE41d2489571d322189246DaFA5ebDe1F4699F498)) { // ZRX
            return ICompoundToken(0xB3319f5D18Bc0D84dD1b4825Dcde5d5f7266d407);
        }
        if (token == IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7)) { // USDT
            return ICompoundToken(0xf650C3d88D12dB855b8bf7D11Be6C55A4e07dCC9);
        }

        return ICompoundToken(0);
    }

    function _getAaveToken(IERC20 token) internal pure returns(IAaveToken) {
        if (token.isETH()) { // ETH
            return IAaveToken(0x3a3A65aAb0dd2A17E3F1947bA16138cd37d08c04);
        }
        if (token == IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F)) { // DAI
            return IAaveToken(0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d);
        }
        if (token == IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)) { // USDC
            return IAaveToken(0x9bA00D6856a4eDF4665BcA2C2309936572473B7E);
        }
        if (token == IERC20(0x57Ab1ec28D129707052df4dF418D58a2D46d5f51)) { // SUSD
            return IAaveToken(0x625aE63000f46200499120B906716420bd059240);
        }
        if (token == IERC20(0x4Fabb145d64652a948d72533023f6E7A623C7C53)) { // BUSD
            return IAaveToken(0x6Ee0f7BB50a54AB5253dA0667B0Dc2ee526C30a8);
        }
        if (token == IERC20(0x0000000000085d4780B73119b644AE5ecd22b376)) { // TUSD
            return IAaveToken(0x4DA9b813057D04BAef4e5800E36083717b4a0341);
        }
        if (token == IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7)) { // USDT
            return IAaveToken(0x71fc860F7D3A592A4a98740e39dB31d25db65ae8);
        }
        if (token == IERC20(0x0D8775F648430679A709E98d2b0Cb6250d2887EF)) { // BAT
            return IAaveToken(0xE1BA0FB44CCb0D11b80F92f4f8Ed94CA3fF51D00);
        }
        if (token == IERC20(0xdd974D5C2e2928deA5F71b9825b8b646686BD200)) { // KNC
            return IAaveToken(0x9D91BE44C06d373a8a226E1f3b146956083803eB);
        }
        if (token == IERC20(0x80fB784B7eD66730e8b1DBd9820aFD29931aab03)) { // LEND
            return IAaveToken(0x7D2D3688Df45Ce7C552E19c27e007673da9204B8);
        }
        if (token == IERC20(0x514910771AF9Ca656af840dff83E8264EcF986CA)) { // LINK
            return IAaveToken(0xA64BD6C70Cb9051F6A9ba1F163Fdc07E0DfB5F84);
        }
        if (token == IERC20(0x0F5D2fB29fb7d3CFeE444a200298f468908cC942)) { // MANA
            return IAaveToken(0x6FCE4A401B6B80ACe52baAefE4421Bd188e76F6f);
        }
        if (token == IERC20(0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2)) { // MKR
            return IAaveToken(0x7deB5e830be29F91E298ba5FF1356BB7f8146998);
        }
        if (token == IERC20(0x1985365e9f78359a9B6AD760e32412f4a445E862)) { // REP
            return IAaveToken(0x71010A9D003445aC60C4e6A7017c1E89A477B438);
        }
        if (token == IERC20(0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F)) { // SNX
            return IAaveToken(0x328C4c80BC7aCa0834Db37e6600A6c49E12Da4DE);
        }
        if (token == IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599)) { // WBTC
            return IAaveToken(0xFC4B8ED459e00e5400be803A9BB3954234FD50e3);
        }
        if (token == IERC20(0xE41d2489571d322189246DaFA5ebDe1F4699F498)) { // ZRX
            return IAaveToken(0x6Fb0855c404E09c47C3fBCA25f08d4E41f9F062f);
        }

        return IAaveToken(0);
    }

    function _scaleDestTokenEthPriceTimesGasPrice(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 destTokenEthPriceTimesGasPrice
    ) internal view returns(uint256) {
        uint256 mul = _cheapGetPrice(ETH_ADDRESS, destToken, 1e16);
        uint256 div = _cheapGetPrice(ETH_ADDRESS, fromToken, 1e16);
        if (div > 0) {
            return destTokenEthPriceTimesGasPrice.mul(mul).div(div);
        }
        return 0;
    }

    function _cheapGetPrice(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal view returns(uint256 returnAmount) {
        (returnAmount,,) = this.getExpectedReturnWithGas(
            fromToken,
            destToken,
            amount,
            1,
            FLAG_DISABLE_SPLIT_RECALCULATION |
            FLAG_DISABLE_ALL_SPLIT_SOURCES |
            FLAG_DISABLE_UNISWAP_V2_ALL |
            FLAG_DISABLE_UNISWAP,
            0
        );
    }

    function _linearInterpolation(
        uint256 value,
        uint256 parts
    ) internal pure returns(uint256[] memory rets) {
        rets = new uint256[](parts);
        for (uint i = 0; i < parts; i++) {
            rets[i] = value.mul(i + 1).div(parts);
        }
    }

    function _tokensEqual(IERC20 tokenA, IERC20 tokenB) internal pure returns(bool) {
        return ((tokenA.isETH() && tokenB.isETH()) || tokenA == tokenB);
    }
}


contract OneSplitViewWrapBase is IOneSplitView, OneSplitRoot {
    function getExpectedReturn(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags // See constants in IOneSplit.sol
    )
        public
        view
        returns(
            uint256 returnAmount,
            uint256[] memory distribution
        )
    {
        (returnAmount, , distribution) = this.getExpectedReturnWithGas(
            fromToken,
            destToken,
            amount,
            parts,
            flags,
            0
        );
    }

    function getExpectedReturnWithGas(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags,
        uint256 destTokenEthPriceTimesGasPrice
    )
        public
        view
        returns(
            uint256 returnAmount,
            uint256 estimateGasAmount,
            uint256[] memory distribution
        )
    {
        return _getExpectedReturnRespectingGasFloor(
            fromToken,
            destToken,
            amount,
            parts,
            flags,
            destTokenEthPriceTimesGasPrice
        );
    }

    function _getExpectedReturnRespectingGasFloor(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags, // See constants in IOneSplit.sol
        uint256 destTokenEthPriceTimesGasPrice
    )
        internal
        view
        returns(
            uint256 returnAmount,
            uint256 estimateGasAmount,
            uint256[] memory distribution
        );
}


contract OneSplitView is IOneSplitView, OneSplitRoot {
    function getExpectedReturn(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags // See constants in IOneSplit.sol
    )
        public
        view
        returns(
            uint256 returnAmount,
            uint256[] memory distribution
        )
    {
        (returnAmount, , distribution) = getExpectedReturnWithGas(
            fromToken,
            destToken,
            amount,
            parts,
            flags,
            0
        );
    }

    function getExpectedReturnWithGas(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags, // See constants in IOneSplit.sol
        uint256 destTokenEthPriceTimesGasPrice
    )
        public
        view
        returns(
            uint256 returnAmount,
            uint256 estimateGasAmount,
            uint256[] memory distribution
        )
    {
        distribution = new uint256[](DEXES_COUNT);

        if (fromToken == destToken) {
            return (amount, 0, distribution);
        }

        function(IERC20,IERC20,uint256,uint256,uint256) view returns(uint256[] memory, uint256)[DEXES_COUNT] memory reserves = _getAllReserves(flags);

        int256[][] memory matrix = new int256[][](DEXES_COUNT);
        uint256[DEXES_COUNT] memory gases;
        bool atLeastOnePositive = false;
        for (uint i = 0; i < DEXES_COUNT; i++) {
            uint256[] memory rets;
            (rets, gases[i]) = reserves[i](fromToken, destToken, amount, parts, flags);

            // Prepend zero and sub gas
            int256 gas = int256(gases[i].mul(destTokenEthPriceTimesGasPrice).div(1e18));
            matrix[i] = new int256[](parts + 1);
            for (uint j = 0; j < parts; j++) {
                matrix[i][j + 1] = int256(rets[j]) - gas;
                atLeastOnePositive = atLeastOnePositive || (matrix[i][j + 1] > 0);
            }
        }

        if (!atLeastOnePositive) {
            for (uint i = 0; i < DEXES_COUNT; i++) {
                for (uint j = 1; j < parts + 1; j++) {
                    if (matrix[i][j] == 0) {
                        matrix[i][j] = VERY_NEGATIVE_VALUE;
                    }
                }
            }
        }

        (, distribution) = _findBestDistribution(parts, matrix);

        (returnAmount, estimateGasAmount) = _getReturnAndGasByDistribution(
            Args({
                fromToken: fromToken,
                destToken: destToken,
                amount: amount,
                parts: parts,
                flags: flags,
                destTokenEthPriceTimesGasPrice: destTokenEthPriceTimesGasPrice,
                distribution: distribution,
                matrix: matrix,
                gases: gases,
                reserves: reserves
            })
        );
        return (returnAmount, estimateGasAmount, distribution);
    }

    struct Args {
        IERC20 fromToken;
        IERC20 destToken;
        uint256 amount;
        uint256 parts;
        uint256 flags;
        uint256 destTokenEthPriceTimesGasPrice;
        uint256[] distribution;
        int256[][] matrix;
        uint256[DEXES_COUNT] gases;
        function(IERC20,IERC20,uint256,uint256,uint256) view returns(uint256[] memory, uint256)[DEXES_COUNT] reserves;
    }

    function _getReturnAndGasByDistribution(
        Args memory args
    ) internal view returns(uint256 returnAmount, uint256 estimateGasAmount) {
        bool[DEXES_COUNT] memory exact = [
            true,  // "Uniswap",
            false, // "Kyber",
            false, // "Bancor",
            false, // "Oasis",
            false, // "Curve Compound",
            false, // "Curve USDT",
            false, // "Curve Y",
            false, // "Curve Binance",
            false, // "CurveSynthetix",
            true,  // "Uniswap Compound",
            true,  // "Uniswap CHAI",
            true,  // "Uniswap Aave",
            false, // "Mooniswap",
            true,  // "Uniswap V2",
            true,  // "Uniswap V2 (ETH)",
            true,  // "Uniswap V2 (DAI)",
            true,  // "Uniswap V2 (USDC)",
            false, // "Curve Pax",
            false, // "Curve RenBTC",
            false, // "Curve tBTC",
            true,  // "Dforce XSwap",
            false, // "Shell",
            true,  // "mStable",
            false, // "Curve sBTC"
            true,  // "Balancer 1"
            true,  // "Balancer 2"
            true   // "Balancer 3"
        ];

        for (uint i = 0; i < DEXES_COUNT; i++) {
            if (args.distribution[i] > 0) {
                if (args.distribution[i] == args.parts || exact[i] || args.flags.check(FLAG_DISABLE_SPLIT_RECALCULATION)) {
                    estimateGasAmount = estimateGasAmount.add(args.gases[i]);
                    int256 value = args.matrix[i][args.distribution[i]];
                    returnAmount = returnAmount.add(uint256(
                        (value == VERY_NEGATIVE_VALUE ? 0 : value) +
                        int256(args.gases[i].mul(args.destTokenEthPriceTimesGasPrice).div(1e18))
                    ));
                }
                else {
                    (uint256[] memory rets, uint256 gas) = args.reserves[i](args.fromToken, args.destToken, args.amount.mul(args.distribution[i]).div(args.parts), 1, args.flags);
                    estimateGasAmount = estimateGasAmount.add(gas);
                    returnAmount = returnAmount.add(rets[0]);
                }
            }
        }
    }

    function _getAllReserves(uint256 flags)
        internal
        pure
        returns(function(IERC20,IERC20,uint256,uint256,uint256) view returns(uint256[] memory, uint256)[DEXES_COUNT] memory)
    {
        bool invert = flags.check(FLAG_DISABLE_ALL_SPLIT_SOURCES);
        return [
            invert != flags.check(FLAG_DISABLE_UNISWAP_ALL | FLAG_DISABLE_UNISWAP)            ? _calculateNoReturn : calculateUniswap,
            invert != flags.check(FLAG_DISABLE_KYBER)                                         ? _calculateNoReturn : calculateKyber,
            invert != flags.check(FLAG_DISABLE_BANCOR)                                        ? _calculateNoReturn : calculateBancor,
            invert != flags.check(FLAG_DISABLE_OASIS)                                         ? _calculateNoReturn : calculateOasis,
            invert != flags.check(FLAG_DISABLE_CURVE_ALL | FLAG_DISABLE_CURVE_COMPOUND)       ? _calculateNoReturn : calculateCurveCompound,
            invert != flags.check(FLAG_DISABLE_CURVE_ALL | FLAG_DISABLE_CURVE_USDT)           ? _calculateNoReturn : calculateCurveUSDT,
            invert != flags.check(FLAG_DISABLE_CURVE_ALL | FLAG_DISABLE_CURVE_Y)              ? _calculateNoReturn : calculateCurveY,
            invert != flags.check(FLAG_DISABLE_CURVE_ALL | FLAG_DISABLE_CURVE_BINANCE)        ? _calculateNoReturn : calculateCurveBinance,
            invert != flags.check(FLAG_DISABLE_CURVE_ALL | FLAG_DISABLE_CURVE_SYNTHETIX)      ? _calculateNoReturn : calculateCurveSynthetix,
            invert != flags.check(FLAG_DISABLE_UNISWAP_ALL | FLAG_DISABLE_UNISWAP_COMPOUND)   ? _calculateNoReturn : calculateUniswapCompound,
            invert != flags.check(FLAG_DISABLE_UNISWAP_ALL | FLAG_DISABLE_UNISWAP_CHAI)       ? _calculateNoReturn : calculateUniswapChai,
            invert != flags.check(FLAG_DISABLE_UNISWAP_ALL | FLAG_DISABLE_UNISWAP_AAVE)       ? _calculateNoReturn : calculateUniswapAave,
            invert != flags.check(FLAG_DISABLE_MOONISWAP)                                     ? _calculateNoReturn : calculateMooniswap,
            invert != flags.check(FLAG_DISABLE_UNISWAP_V2_ALL | FLAG_DISABLE_UNISWAP_V2)      ? _calculateNoReturn : calculateUniswapV2,
            invert != flags.check(FLAG_DISABLE_UNISWAP_V2_ALL | FLAG_DISABLE_UNISWAP_V2_ETH)  ? _calculateNoReturn : calculateUniswapV2ETH,
            invert != flags.check(FLAG_DISABLE_UNISWAP_V2_ALL | FLAG_DISABLE_UNISWAP_V2_DAI)  ? _calculateNoReturn : calculateUniswapV2DAI,
            invert != flags.check(FLAG_DISABLE_UNISWAP_V2_ALL | FLAG_DISABLE_UNISWAP_V2_USDC) ? _calculateNoReturn : calculateUniswapV2USDC,
            invert != flags.check(FLAG_DISABLE_CURVE_ALL | FLAG_DISABLE_CURVE_PAX)            ? _calculateNoReturn : calculateCurvePAX,
            invert != flags.check(FLAG_DISABLE_CURVE_ALL | FLAG_DISABLE_CURVE_RENBTC)         ? _calculateNoReturn : calculateCurveRenBTC,
            invert != flags.check(FLAG_DISABLE_CURVE_ALL | FLAG_DISABLE_CURVE_TBTC)           ? _calculateNoReturn : calculateCurveTBTC,
            invert != flags.check(FLAG_DISABLE_DFORCE_SWAP)                                   ? _calculateNoReturn : calculateDforceSwap,
            invert != flags.check(FLAG_DISABLE_SHELL)                                         ? _calculateNoReturn : calculateShell,
            invert != flags.check(FLAG_DISABLE_MSTABLE_MUSD)                                  ? _calculateNoReturn : calculateMStableMUSD,
            invert != flags.check(FLAG_DISABLE_CURVE_ALL | FLAG_DISABLE_CURVE_SBTC)           ? _calculateNoReturn : calculateCurveSBTC,
            invert != flags.check(FLAG_DISABLE_BALANCER_ALL | FLAG_DISABLE_BALANCER_1)        ? _calculateNoReturn : calculateBalancer1,
            invert != flags.check(FLAG_DISABLE_BALANCER_ALL | FLAG_DISABLE_BALANCER_2)        ? _calculateNoReturn : calculateBalancer2,
            invert != flags.check(FLAG_DISABLE_BALANCER_ALL | FLAG_DISABLE_BALANCER_3)        ? _calculateNoReturn : calculateBalancer3
        ];
    }

    function _calculateNoGas(
        IERC20 /*fromToken*/,
        IERC20 /*destToken*/,
        uint256 /*amount*/,
        uint256 /*parts*/,
        uint256 /*destTokenEthPriceTimesGasPrice*/,
        uint256 /*flags*/,
        uint256 /*destTokenEthPrice*/
    ) internal view returns(uint256[] memory /*rets*/, uint256 /*gas*/) {
        this;
    }

    // View Helpers

    function _calculateBalancer(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 /*flags*/,
        uint256 poolIndex
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        address[] memory pools = balancerRegistry.getBestPoolsWithLimit(
            address(fromToken.isETH() ? weth : fromToken),
            address(destToken.isETH() ? weth : destToken),
            poolIndex + 1
        );
        if (poolIndex >= pools.length) {
            return (new uint256[](parts), 0);
        }

        return (
            balancerRegistry.getPoolReturns(
                pools[poolIndex],
                address(fromToken.isETH() ? weth : fromToken),
                address(destToken.isETH() ? weth : destToken),
                _linearInterpolation(amount, parts)
            ),
            100_000
        );
    }

    function calculateBalancer1(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        return _calculateBalancer(
            fromToken,
            destToken,
            amount,
            parts,
            flags,
            0
        );
    }

    function calculateBalancer2(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        return _calculateBalancer(
            fromToken,
            destToken,
            amount,
            parts,
            flags,
            1
        );
    }

    function calculateBalancer3(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        return _calculateBalancer(
            fromToken,
            destToken,
            amount,
            parts,
            flags,
            2
        );
    }

    function calculateMStableMUSD(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 /*flags*/
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        rets = new uint256[](parts);

        if ((fromToken != usdc && fromToken != dai && fromToken != usdt && fromToken != tusd) ||
            (destToken != usdc && destToken != dai && destToken != usdt && destToken != tusd))
        {
            return (rets, 0);
        }

        for (uint i = 1; i <= parts; i *= 2) {
            (bool success, bytes memory data) = address(musd).staticcall(abi.encodeWithSelector(
                musd.getSwapOutput.selector,
                fromToken,
                destToken,
                amount.mul(parts.div(i)).div(parts)
            ));

            if (success && data.length > 0) {
                (,, uint256 maxRet) = abi.decode(data, (bool,string,uint256));
                if (maxRet > 0) {
                    for (uint j = 0; j < parts.div(i); j++) {
                        rets[j] = maxRet.mul(j + 1).div(parts.div(i));
                    }
                    break;
                }
            }
        }

        return (
            rets,
            700_000
        );
    }

    function _calculateCurveSelector(
        ICurve curve,
        bytes4 sel,
        IERC20[] memory tokens,
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 /*flags*/
    ) internal view returns(uint256[] memory rets) {
        int128 i = 0;
        int128 j = 0;
        for (uint t = 0; t < tokens.length; t++) {
            if (fromToken == tokens[t]) {
                i = int128(t + 1);
            }
            if (destToken == tokens[t]) {
                j = int128(t + 1);
            }
        }

        if (i == 0 || j == 0) {
            return new uint256[](parts);
        }

        // curve.get_dy(i - 1, j - 1, amount);
        // curve.get_dy_underlying(i - 1, j - 1, amount);
        (bool success, bytes memory data) = address(curve).staticcall(abi.encodeWithSelector(sel, i - 1, j - 1, amount));
        uint256 maxRet = (!success || data.length == 0) ? 0 : abi.decode(data, (uint256));

        return _linearInterpolation(maxRet, parts);
    }

    function calculateCurveCompound(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = dai;
        tokens[1] = usdc;
        return (_calculateCurveSelector(
            curveCompound,
            curveCompound.get_dy_underlying.selector,
            tokens,
            fromToken,
            destToken,
            amount,
            parts,
            flags
        ), 720_000);
    }

    function calculateCurveUSDT(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        IERC20[] memory tokens = new IERC20[](3);
        tokens[0] = dai;
        tokens[1] = usdc;
        tokens[2] = usdt;
        return (_calculateCurveSelector(
            curveUSDT,
            curveUSDT.get_dy_underlying.selector,
            tokens,
            fromToken,
            destToken,
            amount,
            parts,
            flags
        ), 720_000);
    }

    function calculateCurveY(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        IERC20[] memory tokens = new IERC20[](4);
        tokens[0] = dai;
        tokens[1] = usdc;
        tokens[2] = usdt;
        tokens[3] = tusd;
        return (_calculateCurveSelector(
            curveY,
            curveY.get_dy_underlying.selector,
            tokens,
            fromToken,
            destToken,
            amount,
            parts,
            flags
        ), 1_400_000);
    }

    function calculateCurveBinance(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        IERC20[] memory tokens = new IERC20[](4);
        tokens[0] = dai;
        tokens[1] = usdc;
        tokens[2] = usdt;
        tokens[3] = busd;
        return (_calculateCurveSelector(
            curveBinance,
            curveBinance.get_dy_underlying.selector,
            tokens,
            fromToken,
            destToken,
            amount,
            parts,
            flags
        ), 1_400_000);
    }

    function calculateCurveSynthetix(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        IERC20[] memory tokens = new IERC20[](4);
        tokens[0] = dai;
        tokens[1] = usdc;
        tokens[2] = usdt;
        tokens[3] = susd;
        return (_calculateCurveSelector(
            curveSynthetix,
            curveSynthetix.get_dy_underlying.selector,
            tokens,
            fromToken,
            destToken,
            amount,
            parts,
            flags
        ), 200_000);
    }

    function calculateCurvePAX(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        IERC20[] memory tokens = new IERC20[](4);
        tokens[0] = dai;
        tokens[1] = usdc;
        tokens[2] = usdt;
        tokens[3] = pax;
        return (_calculateCurveSelector(
            curvePAX,
            curvePAX.get_dy_underlying.selector,
            tokens,
            fromToken,
            destToken,
            amount,
            parts,
            flags
        ), 1_000_000);
    }

    function calculateCurveRenBTC(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = renbtc;
        tokens[1] = wbtc;
        return (_calculateCurveSelector(
            curveRenBTC,
            curveRenBTC.get_dy.selector,
            tokens,
            fromToken,
            destToken,
            amount,
            parts,
            flags
        ), 130_000);
    }

    function calculateCurveTBTC(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        IERC20[] memory tokens = new IERC20[](3);
        tokens[0] = tbtc;
        tokens[1] = wbtc;
        tokens[2] = hbtc;
        return (_calculateCurveSelector(
            curveTBTC,
            curveTBTC.get_dy.selector,
            tokens,
            fromToken,
            destToken,
            amount,
            parts,
            flags
        ), 145_000);
    }

    function calculateCurveSBTC(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        IERC20[] memory tokens = new IERC20[](3);
        tokens[0] = renbtc;
        tokens[1] = wbtc;
        tokens[2] = sbtc;
        return (_calculateCurveSelector(
            curveSBTC,
            curveSBTC.get_dy.selector,
            tokens,
            fromToken,
            destToken,
            amount,
            parts,
            flags
        ), 150_000);
    }

    function calculateShell(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 /*flags*/
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        (bool success, bytes memory data) = address(shell).staticcall(abi.encodeWithSelector(
            shell.viewOriginTrade.selector,
            fromToken,
            destToken,
            amount
        ));

        if (!success || data.length == 0) {
            return (new uint256[](parts), 0);
        }

        uint256 maxRet = abi.decode(data, (uint256));
        return (_linearInterpolation(maxRet, parts), 300_000);
    }

    function calculateDforceSwap(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 /*flags*/
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        (bool success, bytes memory data) = address(dforceSwap).staticcall(
            abi.encodeWithSelector(
                dforceSwap.getAmountByInput.selector,
                fromToken,
                destToken,
                amount
            )
        );
        if (!success || data.length == 0) {
            return (new uint256[](parts), 0);
        }

        uint256 maxRet = abi.decode(data, (uint256));
        uint256 available = destToken.universalBalanceOf(address(dforceSwap));
        if (maxRet > available) {
            return (new uint256[](parts), 0);
        }

        return (_linearInterpolation(maxRet, parts), 160_000);
    }

    function _calculateUniswapFormula(uint256 fromBalance, uint256 toBalance, uint256 amount) internal pure returns(uint256) {
        return amount.mul(toBalance).mul(997).div(
            fromBalance.mul(1000).add(amount.mul(997))
        );
    }

    function _calculateUniswap(
        IERC20 fromToken,
        IERC20 destToken,
        uint256[] memory amounts,
        uint256 /*flags*/
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        rets = amounts;

        if (!fromToken.isETH()) {
            IUniswapExchange fromExchange = uniswapFactory.getExchange(fromToken);
            if (fromExchange == IUniswapExchange(0)) {
                return (new uint256[](rets.length), 0);
            }

            uint256 fromTokenBalance = fromToken.universalBalanceOf(address(fromExchange));
            uint256 fromEtherBalance = address(fromExchange).balance;

            for (uint i = 0; i < rets.length; i++) {
                rets[i] = _calculateUniswapFormula(fromTokenBalance, fromEtherBalance, rets[i]);
            }
        }

        if (!destToken.isETH()) {
            IUniswapExchange toExchange = uniswapFactory.getExchange(destToken);
            if (toExchange == IUniswapExchange(0)) {
                return (new uint256[](rets.length), 0);
            }

            uint256 toEtherBalance = address(toExchange).balance;
            uint256 toTokenBalance = destToken.universalBalanceOf(address(toExchange));

            for (uint i = 0; i < rets.length; i++) {
                rets[i] = _calculateUniswapFormula(toEtherBalance, toTokenBalance, rets[i]);
            }
        }

        return (rets, fromToken.isETH() || destToken.isETH() ? 60_000 : 100_000);
    }

    function calculateUniswap(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        return _calculateUniswap(
            fromToken,
            destToken,
            _linearInterpolation(amount, parts),
            flags
        );
    }

    function _calculateUniswapWrapped(
        IERC20 fromToken,
        IERC20 midToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 midTokenPrice,
        uint256 flags,
        uint256 gas1,
        uint256 gas2
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        if (!fromToken.isETH() && destToken.isETH()) {
            (rets, gas) = _calculateUniswap(
                midToken,
                destToken,
                _linearInterpolation(amount.mul(1e18).div(midTokenPrice), parts),
                flags
            );
            return (rets, gas + gas1);
        }
        else if (fromToken.isETH() && !destToken.isETH()) {
            (rets, gas) = _calculateUniswap(
                fromToken,
                midToken,
                _linearInterpolation(amount, parts),
                flags
            );

            for (uint i = 0; i < parts; i++) {
                rets[i] = rets[i].mul(midTokenPrice).div(1e18);
            }
            return (rets, gas + gas2);
        }

        return (new uint256[](parts), 0);
    }

    function calculateUniswapCompound(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        IERC20 midPreToken;
        if (!fromToken.isETH() && destToken.isETH()) {
            midPreToken = fromToken;
        }
        else if (!destToken.isETH() && fromToken.isETH()) {
            midPreToken = destToken;
        }

        if (!midPreToken.isETH()) {
            ICompoundToken midToken = _getCompoundToken(midPreToken);
            if (midToken != ICompoundToken(0)) {
                return _calculateUniswapWrapped(
                    fromToken,
                    midToken,
                    destToken,
                    amount,
                    parts,
                    midToken.exchangeRateStored(),
                    flags,
                    200_000,
                    200_000
                );
            }
        }

        return (new uint256[](parts), 0);
    }

    function calculateUniswapChai(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        if (fromToken == dai && destToken.isETH() ||
            fromToken.isETH() && destToken == dai)
        {
            return _calculateUniswapWrapped(
                fromToken,
                chai,
                destToken,
                amount,
                parts,
                chai.chaiPrice(),
                flags,
                180_000,
                160_000
            );
        }

        return (new uint256[](parts), 0);
    }

    function calculateUniswapAave(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        IERC20 midPreToken;
        if (!fromToken.isETH() && destToken.isETH()) {
            midPreToken = fromToken;
        }
        else if (!destToken.isETH() && fromToken.isETH()) {
            midPreToken = destToken;
        }

        if (!midPreToken.isETH()) {
            IAaveToken midToken = _getAaveToken(midPreToken);
            if (midToken != IAaveToken(0)) {
                return _calculateUniswapWrapped(
                    fromToken,
                    midToken,
                    destToken,
                    amount,
                    parts,
                    1e18,
                    flags,
                    310_000,
                    670_000
                );
            }
        }

        return (new uint256[](parts), 0);
    }

    function _calculateKyber(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 flags
    ) internal view returns(uint256 returnAmount, uint256 gas) {
        (bool success, bytes memory data) = address(kyberNetworkProxy).staticcall.gas(2300)(abi.encodeWithSelector(
            kyberNetworkProxy.kyberNetworkContract.selector
        ));
        if (!success || data.length == 0) {
            return (0, 0);
        }

        IKyberNetworkContract kyberNetworkContract = IKyberNetworkContract(abi.decode(data, (address)));

        if (fromToken.isETH() || destToken.isETH()) {
            return _calculateKyberWithEth(kyberNetworkContract, fromToken, destToken, amount, flags);
        }

        (uint256 value, uint256 gasFee) = _calculateKyberWithEth(kyberNetworkContract, fromToken, ETH_ADDRESS, amount, flags);
        if (value == 0) {
            return (0, 0);
        }

        (uint256 value2, uint256 gasFee2) =  _calculateKyberWithEth(kyberNetworkContract, ETH_ADDRESS, destToken, value, flags);
        return (value2, gasFee + gasFee2);
    }

    function _calculateKyberWithEth(
        IKyberNetworkContract kyberNetworkContract,
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 flags
    ) internal view returns(uint256 returnAmount, uint256 gas) {
        require(fromToken.isETH() || destToken.isETH(), "2ETH");

        (bool success, bytes memory data) = address(kyberNetworkContract).staticcall.gas(1500000)(abi.encodeWithSelector(
            kyberNetworkContract.searchBestRate.selector,
            fromToken.isETH() ? ETH_ADDRESS : fromToken,
            destToken.isETH() ? ETH_ADDRESS : destToken,
            amount,
            true
        ));
        if (!success) {
            return (0, 0);
        }

        (address reserve, uint256 ret) = abi.decode(data, (address,uint256));

        if (ret == 0) {
            return (0, 0);
        }

        if ((reserve == 0x31E085Afd48a1d6e51Cc193153d625e8f0514C7F && !flags.check(FLAG_ENABLE_KYBER_UNISWAP_RESERVE)) ||
            (reserve == 0x1E158c0e93c30d24e918Ef83d1e0bE23595C3c0f && !flags.check(FLAG_ENABLE_KYBER_OASIS_RESERVE)) ||
            (reserve == 0x053AA84FCC676113a57e0EbB0bD1913839874bE4 && !flags.check(FLAG_ENABLE_KYBER_BANCOR_RESERVE)))
        {
            return (0, 0);
        }

        if (!flags.check(FLAG_ENABLE_KYBER_UNISWAP_RESERVE)) {
            (success,) = reserve.staticcall.gas(2300)(abi.encodeWithSelector(
                IKyberUniswapReserve(reserve).uniswapFactory.selector
            ));
            if (success) {
                return (0, 0);
            }
        }

        if (!flags.check(FLAG_ENABLE_KYBER_OASIS_RESERVE)) {
            (success,) = reserve.staticcall.gas(2300)(abi.encodeWithSelector(
                IKyberOasisReserve(reserve).otc.selector
            ));
            if (success) {
                return (0, 0);
            }
        }

        if (!flags.check(FLAG_ENABLE_KYBER_BANCOR_RESERVE)) {
            (success,) = reserve.staticcall.gas(2300)(abi.encodeWithSelector(
                IKyberBancorReserve(reserve).bancorEth.selector
            ));
            if (success) {
                return (0, 0);
            }
        }

        return (
            ret.mul(amount)
                .mul(10 ** IERC20(destToken).universalDecimals())
                .div(10 ** IERC20(fromToken).universalDecimals())
                .div(1e18),
            700_000
        );
    }

    function calculateKyber(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        rets = new uint256[](parts);
        for (uint i = 0; i < parts; i++) {
            (rets[i], gas) = _calculateKyber(fromToken, destToken, amount.mul(i + 1).div(parts), flags);
            if (rets[i] == 0) {
                break;
            }
        }

        return (rets, gas);
    }

    function calculateBancor(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 /*flags*/
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        IBancorNetwork bancorNetwork = IBancorNetwork(bancorContractRegistry.addressOf("BancorNetwork"));
        address[] memory path = _buildBancorPath(fromToken, destToken);

        rets = _linearInterpolation(amount, parts);
        for (uint i = 0; i < parts; i++) {
            (bool success, bytes memory data) = address(bancorNetwork).staticcall.gas(500000)(
                abi.encodeWithSelector(
                    bancorNetwork.getReturnByPath.selector,
                    path,
                    rets[i]
                )
            );
            if (!success || data.length == 0) {
                for (; i < parts; i++) {
                    rets[i] = 0;
                }
                break;
            } else {
                (uint256 ret,) = abi.decode(data, (uint256,uint256));
                rets[i] = ret;
            }
        }

        return (rets, path.length.mul(150_000));
    }

    function calculateOasis(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 /*flags*/
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        rets = _linearInterpolation(amount, parts);
        for (uint i = 0; i < parts; i++) {
            (bool success, bytes memory data) = address(oasisExchange).staticcall.gas(500000)(
                abi.encodeWithSelector(
                    oasisExchange.getBuyAmount.selector,
                    destToken.isETH() ? weth : destToken,
                    fromToken.isETH() ? weth : fromToken,
                    rets[i]
                )
            );

            if (!success || data.length == 0) {
                for (; i < parts; i++) {
                    rets[i] = 0;
                }
                break;
            } else {
                rets[i] = abi.decode(data, (uint256));
            }
        }

        return (rets, 500_000);
    }

    function calculateMooniswap(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 /*flags*/
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        IMooniswap mooniswap = mooniswapRegistry.target();
        (bool success, bytes memory data) = address(mooniswap).staticcall.gas(1000000)(
            abi.encodeWithSelector(
                mooniswap.getReturn.selector,
                fromToken,
                destToken,
                amount
            )
        );

        if (!success || data.length == 0) {
            return (new uint256[](parts), 0);
        }

        uint256 maxRet = abi.decode(data, (uint256));
        return (_linearInterpolation(maxRet, parts), 1_000_000);
    }

    function calculateUniswapV2(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        return _calculateUniswapV2(
            fromToken,
            destToken,
            _linearInterpolation(amount, parts),
            flags
        );
    }

    function calculateUniswapV2ETH(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        if (fromToken.isETH() || fromToken == weth || destToken.isETH() || destToken == weth) {
            return (new uint256[](parts), 0);
        }

        return _calculateUniswapV2OverMidToken(
            fromToken,
            weth,
            destToken,
            amount,
            parts,
            flags
        );
    }

    function calculateUniswapV2DAI(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        if (fromToken == dai || destToken == dai) {
            return (new uint256[](parts), 0);
        }

        return _calculateUniswapV2OverMidToken(
            fromToken,
            dai,
            destToken,
            amount,
            parts,
            flags
        );
    }

    function calculateUniswapV2USDC(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        if (fromToken == usdc || destToken == usdc) {
            return (new uint256[](parts), 0);
        }

        return _calculateUniswapV2OverMidToken(
            fromToken,
            usdc,
            destToken,
            amount,
            parts,
            flags
        );
    }

    function _calculateUniswapV2(
        IERC20 fromToken,
        IERC20 destToken,
        uint256[] memory amounts,
        uint256 /*flags*/
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        rets = new uint256[](amounts.length);

        IERC20 fromTokenReal = fromToken.isETH() ? weth : fromToken;
        IERC20 destTokenReal = destToken.isETH() ? weth : destToken;
        IUniswapV2Exchange exchange = uniswapV2.getPair(fromTokenReal, destTokenReal);
        if (exchange != IUniswapV2Exchange(0)) {
            uint256 fromTokenBalance = fromTokenReal.universalBalanceOf(address(exchange));
            uint256 destTokenBalance = destTokenReal.universalBalanceOf(address(exchange));
            for (uint i = 0; i < amounts.length; i++) {
                rets[i] = _calculateUniswapFormula(fromTokenBalance, destTokenBalance, amounts[i]);
            }
            return (rets, 50_000);
        }
    }

    function _calculateUniswapV2OverMidToken(
        IERC20 fromToken,
        IERC20 midToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        rets = _linearInterpolation(amount, parts);

        uint256 gas1;
        uint256 gas2;
        (rets, gas1) = _calculateUniswapV2(fromToken, midToken, rets, flags);
        (rets, gas2) = _calculateUniswapV2(midToken, destToken, rets, flags);
        return (rets, gas1 + gas2);
    }

    function _calculateNoReturn(
        IERC20 /*fromToken*/,
        IERC20 /*destToken*/,
        uint256 /*amount*/,
        uint256 parts,
        uint256 /*flags*/
    ) internal view returns(uint256[] memory rets, uint256 gas) {
        this;
        return (new uint256[](parts), 0);
    }
}


contract OneSplitBaseWrap is IOneSplit, OneSplitRoot {
    function _swap(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256[] memory distribution,
        uint256 flags // See constants in IOneSplit.sol
    ) internal {
        if (fromToken == destToken) {
            return;
        }

        _swapFloor(
            fromToken,
            destToken,
            amount,
            distribution,
            flags
        );
    }

    function _swapFloor(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256[] memory distribution,
        uint256 /*flags*/ // See constants in IOneSplit.sol
    ) internal;
}


contract OneSplit is IOneSplit, OneSplitRoot {
    IOneSplitView public oneSplitView;

    constructor(IOneSplitView _oneSplitView) public {
        oneSplitView = _oneSplitView;
    }

    function() external payable {
        // solium-disable-next-line security/no-tx-origin
        require(msg.sender != tx.origin);
    }

    function getExpectedReturn(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    )
        public
        view
        returns(
            uint256 returnAmount,
            uint256[] memory distribution
        )
    {
        (returnAmount, , distribution) = getExpectedReturnWithGas(
            fromToken,
            destToken,
            amount,
            parts,
            flags,
            0
        );
    }

    function getExpectedReturnWithGas(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags,
        uint256 destTokenEthPriceTimesGasPrice
    )
        public
        view
        returns(
            uint256 returnAmount,
            uint256 estimateGasAmount,
            uint256[] memory distribution
        )
    {
        return oneSplitView.getExpectedReturnWithGas(
            fromToken,
            destToken,
            amount,
            parts,
            flags,
            destTokenEthPriceTimesGasPrice
        );
    }

    function swap(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 minReturn,
        uint256[] memory distribution,
        uint256 /*flags*/  // See constants in IOneSplit.sol
    ) public payable returns(uint256 returnAmount) {
        if (fromToken == destToken) {
            return amount;
        }

        function(IERC20,IERC20,uint256) returns(uint256)[DEXES_COUNT] memory reserves = [
            _swapOnUniswap,
            _swapOnKyber,
            _swapOnBancor,
            _swapOnOasis,
            _swapOnCurveCompound,
            _swapOnCurveUSDT,
            _swapOnCurveY,
            _swapOnCurveBinance,
            _swapOnCurveSynthetix,
            _swapOnUniswapCompound,
            _swapOnUniswapChai,
            _swapOnUniswapAave,
            _swapOnMooniswap,
            _swapOnUniswapV2,
            _swapOnUniswapV2ETH,
            _swapOnUniswapV2DAI,
            _swapOnUniswapV2USDC,
            _swapOnCurvePAX,
            _swapOnCurveRenBTC,
            _swapOnCurveTBTC,
            _swapOnDforceSwap,
            _swapOnShell,
            _swapOnMStableMUSD,
            _swapOnCurveSBTC,
            _swapOnBalancer1,
            _swapOnBalancer2,
            _swapOnBalancer3
        ];

        require(distribution.length <= reserves.length, "OneSplit: Distribution array should not exceed reserves array size");

        uint256 parts = 0;
        uint256 lastNonZeroIndex = 0;
        for (uint i = 0; i < distribution.length; i++) {
            if (distribution[i] > 0) {
                parts = parts.add(distribution[i]);
                lastNonZeroIndex = i;
            }
        }

        if (parts == 0) {
            if (fromToken.isETH()) {
                msg.sender.transfer(msg.value);
                return msg.value;
            }
            return amount;
        }

        fromToken.universalTransferFrom(msg.sender, address(this), amount);
        uint256 remainingAmount = fromToken.universalBalanceOf(address(this));

        for (uint i = 0; i < distribution.length; i++) {
            if (distribution[i] == 0) {
                continue;
            }

            uint256 swapAmount = amount.mul(distribution[i]).div(parts);
            if (i == lastNonZeroIndex) {
                swapAmount = remainingAmount;
            }
            remainingAmount -= swapAmount;
            reserves[i](fromToken, destToken, swapAmount);
        }

        returnAmount = destToken.universalBalanceOf(address(this));
        require(returnAmount >= minReturn, "OneSplit: Return amount was not enough");
        destToken.universalTransfer(msg.sender, returnAmount);
        fromToken.universalTransfer(msg.sender, fromToken.universalBalanceOf(address(this)));
    }

    // Swap helpers

    function _swapOnCurveCompound(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {
        int128 i = (fromToken == dai ? 1 : 0) + (fromToken == usdc ? 2 : 0);
        int128 j = (destToken == dai ? 1 : 0) + (destToken == usdc ? 2 : 0);
        if (i == 0 || j == 0) {
            return 0;
        }

        fromToken.universalApprove(address(curveCompound), amount);
        curveCompound.exchange_underlying(i - 1, j - 1, amount, 0);
    }

    function _swapOnCurveUSDT(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {
        int128 i = (fromToken == dai ? 1 : 0) +
            (fromToken == usdc ? 2 : 0) +
            (fromToken == usdt ? 3 : 0);
        int128 j = (destToken == dai ? 1 : 0) +
            (destToken == usdc ? 2 : 0) +
            (destToken == usdt ? 3 : 0);
        if (i == 0 || j == 0) {
            return 0;
        }

        fromToken.universalApprove(address(curveUSDT), amount);
        curveUSDT.exchange_underlying(i - 1, j - 1, amount, 0);
    }

    function _swapOnCurveY(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {
        int128 i = (fromToken == dai ? 1 : 0) +
            (fromToken == usdc ? 2 : 0) +
            (fromToken == usdt ? 3 : 0) +
            (fromToken == tusd ? 4 : 0);
        int128 j = (destToken == dai ? 1 : 0) +
            (destToken == usdc ? 2 : 0) +
            (destToken == usdt ? 3 : 0) +
            (destToken == tusd ? 4 : 0);
        if (i == 0 || j == 0) {
            return 0;
        }

        fromToken.universalApprove(address(curveY), amount);
        curveY.exchange_underlying(i - 1, j - 1, amount, 0);
    }

    function _swapOnCurveBinance(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {
        int128 i = (fromToken == dai ? 1 : 0) +
            (fromToken == usdc ? 2 : 0) +
            (fromToken == usdt ? 3 : 0) +
            (fromToken == busd ? 4 : 0);
        int128 j = (destToken == dai ? 1 : 0) +
            (destToken == usdc ? 2 : 0) +
            (destToken == usdt ? 3 : 0) +
            (destToken == busd ? 4 : 0);
        if (i == 0 || j == 0) {
            return 0;
        }

        fromToken.universalApprove(address(curveBinance), amount);
        curveBinance.exchange_underlying(i - 1, j - 1, amount, 0);
    }

    function _swapOnCurveSynthetix(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {
        int128 i = (fromToken == dai ? 1 : 0) +
            (fromToken == usdc ? 2 : 0) +
            (fromToken == usdt ? 3 : 0) +
            (fromToken == susd ? 4 : 0);
        int128 j = (destToken == dai ? 1 : 0) +
            (destToken == usdc ? 2 : 0) +
            (destToken == usdt ? 3 : 0) +
            (destToken == susd ? 4 : 0);
        if (i == 0 || j == 0) {
            return 0;
        }

        fromToken.universalApprove(address(curveSynthetix), amount);
        curveSynthetix.exchange_underlying(i - 1, j - 1, amount, 0);
    }

    function _swapOnCurvePAX(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {
        int128 i = (fromToken == dai ? 1 : 0) +
            (fromToken == usdc ? 2 : 0) +
            (fromToken == usdt ? 3 : 0) +
            (fromToken == pax ? 4 : 0);
        int128 j = (destToken == dai ? 1 : 0) +
            (destToken == usdc ? 2 : 0) +
            (destToken == usdt ? 3 : 0) +
            (destToken == pax ? 4 : 0);
        if (i == 0 || j == 0) {
            return 0;
        }

        fromToken.universalApprove(address(curvePAX), amount);
        curvePAX.exchange_underlying(i - 1, j - 1, amount, 0);
    }

    function _swapOnShell(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns (uint256) {
        fromToken.universalApprove(address(shell), amount);
        return shell.swapByOrigin(
            address(fromToken),
            address(destToken),
            amount,
            0,
            now + 50
        );
    }

    function _swapOnMStableMUSD(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns (uint256) {
        fromToken.universalApprove(address(musd), amount);
        return musd.swap(
            fromToken,
            destToken,
            amount,
            address(this)
        );
    }

    function _swapOnCurveRenBTC(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {
        int128 i = (fromToken == renbtc ? 1 : 0) +
            (fromToken == wbtc ? 2 : 0);
        int128 j = (destToken == renbtc ? 1 : 0) +
            (destToken == wbtc ? 2 : 0);
        if (i == 0 || j == 0) {
            return 0;
        }

        fromToken.universalApprove(address(curveRenBTC), amount);
        curveRenBTC.exchange(i - 1, j - 1, amount, 0);
    }

    function _swapOnCurveTBTC(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {
        int128 i = (fromToken == tbtc ? 1 : 0) +
            (fromToken == wbtc ? 2 : 0) +
            (fromToken == hbtc ? 3 : 0);
        int128 j = (destToken == tbtc ? 1 : 0) +
            (destToken == wbtc ? 2 : 0) +
            (destToken == hbtc ? 3 : 0);
        if (i == 0 || j == 0) {
            return 0;
        }

        fromToken.universalApprove(address(curveTBTC), amount);
        curveTBTC.exchange(i - 1, j - 1, amount, 0);
    }

    function _swapOnCurveSBTC(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {
        int128 i = (fromToken == renbtc ? 1 : 0) +
            (fromToken == wbtc ? 2 : 0) +
            (fromToken == sbtc ? 3 : 0);
        int128 j = (destToken == renbtc ? 1 : 0) +
            (destToken == wbtc ? 2 : 0) +
            (destToken == sbtc ? 3 : 0);
        if (i == 0 || j == 0) {
            return 0;
        }

        fromToken.universalApprove(address(curveSBTC), amount);
        curveSBTC.exchange(i - 1, j - 1, amount, 0);
    }

    function _swapOnDforceSwap(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {
        fromToken.universalApprove(address(dforceSwap), amount);
        dforceSwap.swap(fromToken, destToken, amount);
    }

    function _swapOnUniswap(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {

        uint256 returnAmount = amount;

        if (!fromToken.isETH()) {
            IUniswapExchange fromExchange = uniswapFactory.getExchange(fromToken);
            if (fromExchange != IUniswapExchange(0)) {
                fromToken.universalApprove(address(fromExchange), returnAmount);
                returnAmount = fromExchange.tokenToEthSwapInput(returnAmount, 1, now);
            }
        }

        if (!destToken.isETH()) {
            IUniswapExchange toExchange = uniswapFactory.getExchange(destToken);
            if (toExchange != IUniswapExchange(0)) {
                returnAmount = toExchange.ethToTokenSwapInput.value(returnAmount)(1, now);
            }
        }

        return returnAmount;
    }

    function _swapOnUniswapCompound(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {
        if (!fromToken.isETH()) {
            ICompoundToken fromCompound = _getCompoundToken(fromToken);
            fromToken.universalApprove(address(fromCompound), amount);
            fromCompound.mint(amount);
            return _swapOnUniswap(IERC20(fromCompound), destToken, IERC20(fromCompound).universalBalanceOf(address(this)));
        }

        if (!destToken.isETH()) {
            ICompoundToken toCompound = _getCompoundToken(destToken);
            uint256 compoundAmount = _swapOnUniswap(fromToken, IERC20(toCompound), amount);
            toCompound.redeem(compoundAmount);
            return destToken.universalBalanceOf(address(this));
        }

        return 0;
    }

    function _swapOnUniswapChai(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {
        if (fromToken == dai) {
            fromToken.universalApprove(address(chai), amount);
            chai.join(address(this), amount);
            return _swapOnUniswap(IERC20(chai), destToken, IERC20(chai).universalBalanceOf(address(this)));
        }

        if (destToken == dai) {
            uint256 chaiAmount = _swapOnUniswap(fromToken, IERC20(chai), amount);
            chai.exit(address(this), chaiAmount);
            return destToken.universalBalanceOf(address(this));
        }

        return 0;
    }

    function _swapOnUniswapAave(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {
        if (!fromToken.isETH()) {
            IAaveToken fromAave = _getAaveToken(fromToken);
            fromToken.universalApprove(aave.core(), amount);
            aave.deposit(fromToken, amount, 1101);
            return _swapOnUniswap(IERC20(fromAave), destToken, IERC20(fromAave).universalBalanceOf(address(this)));
        }

        if (!destToken.isETH()) {
            IAaveToken toAave = _getAaveToken(destToken);
            uint256 aaveAmount = _swapOnUniswap(fromToken, IERC20(toAave), amount);
            toAave.redeem(aaveAmount);
            return aaveAmount;
        }

        return 0;
    }

    function _swapOnMooniswap(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {
        IMooniswap mooniswap = mooniswapRegistry.target();
        fromToken.universalApprove(address(mooniswap), amount);
        return mooniswap.swap.value(fromToken.isETH() ? amount : 0)(
            fromToken,
            destToken,
            amount,
            0
        );
    }

    function _swapOnKyber(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {
        fromToken.universalApprove(address(kyberNetworkProxy), amount);
        return kyberNetworkProxy.tradeWithHint.value(fromToken.isETH() ? amount : 0)(
            fromToken.isETH() ? ETH_ADDRESS : fromToken,
            amount,
            destToken.isETH() ? ETH_ADDRESS : destToken,
            address(this),
            1 << 255,
            0,
            0x4D37f28D2db99e8d35A6C725a5f1749A085850a3,
            ""
        );
    }

    function _swapOnBancor(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {
        IBancorNetwork bancorNetwork = IBancorNetwork(bancorContractRegistry.addressOf("BancorNetwork"));
        address[] memory path = _buildBancorPath(fromToken, destToken);
        fromToken.universalApprove(address(bancorNetwork), amount);
        return bancorNetwork.convert.value(fromToken.isETH() ? amount : 0)(path, amount, 1);
    }

    function _swapOnOasis(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {
        if (fromToken.isETH()) {
            weth.deposit.value(amount)();
        }

        IERC20 approveToken = fromToken.isETH() ? weth : fromToken;
        approveToken.universalApprove(address(oasisExchange), amount);
        uint256 returnAmount = oasisExchange.sellAllAmount(
            fromToken.isETH() ? weth : fromToken,
            amount,
            destToken.isETH() ? weth : destToken,
            1
        );

        if (destToken.isETH()) {
            weth.withdraw(weth.balanceOf(address(this)));
        }

        return returnAmount;
    }

    function _swapOnUniswapV2Internal(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256 returnAmount) {
        if (fromToken.isETH()) {
            weth.deposit.value(amount)();
        }

        IERC20 fromTokenReal = fromToken.isETH() ? weth : fromToken;
        IERC20 toTokenReal = destToken.isETH() ? weth : destToken;
        IUniswapV2Exchange exchange = uniswapV2.getPair(fromTokenReal, toTokenReal);
        returnAmount = exchange.getReturn(fromTokenReal, toTokenReal, amount);

        fromTokenReal.universalTransfer(address(exchange), amount);
        if (uint256(address(fromTokenReal)) < uint256(address(toTokenReal))) {
            exchange.swap(0, returnAmount, address(this), "");
        } else {
            exchange.swap(returnAmount, 0, address(this), "");
        }

        if (destToken.isETH()) {
            weth.withdraw(weth.balanceOf(address(this)));
        }
    }

    function _swapOnUniswapV2OverMid(
        IERC20 fromToken,
        IERC20 midToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {
        return _swapOnUniswapV2Internal(
            midToken,
            destToken,
            _swapOnUniswapV2Internal(
                fromToken,
                midToken,
                amount
            )
        );
    }

    function _swapOnUniswapV2(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {
        return _swapOnUniswapV2Internal(
            fromToken,
            destToken,
            amount
        );
    }

    function _swapOnUniswapV2ETH(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {
        return _swapOnUniswapV2OverMid(
            fromToken,
            weth,
            destToken,
            amount
        );
    }

    function _swapOnUniswapV2DAI(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {
        return _swapOnUniswapV2OverMid(
            fromToken,
            dai,
            destToken,
            amount
        );
    }

    function _swapOnUniswapV2USDC(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {
        return _swapOnUniswapV2OverMid(
            fromToken,
            usdc,
            destToken,
            amount
        );
    }

    function _swapOnBalancerX(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 poolIndex
    ) internal returns(uint256) {
        address[] memory pools = balancerRegistry.getBestPoolsWithLimit(
            address(fromToken.isETH() ? weth : fromToken),
            address(destToken.isETH() ? weth : destToken),
            poolIndex + 1
        );

        if (fromToken.isETH()) {
            weth.deposit.value(amount)();
        }

        (fromToken.isETH() ? weth : destToken).universalApprove(pools[poolIndex], amount);
        IBalancerPool(pools[poolIndex]).swapExactAmountIn(
            fromToken.isETH() ? weth : fromToken,
            amount,
            destToken.isETH() ? weth : destToken,
            0,
            uint256(-1)
        );

        if (destToken.isETH()) {
            weth.withdraw(weth.balanceOf(address(this)));
        }
    }

    function _swapOnBalancer1(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {
        _swapOnBalancerX(fromToken, destToken, amount, 0);
    }

    function _swapOnBalancer2(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {
        _swapOnBalancerX(fromToken, destToken, amount, 1);
    }

    function _swapOnBalancer3(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal returns(uint256) {
        _swapOnBalancerX(fromToken, destToken, amount, 2);
    }
}
