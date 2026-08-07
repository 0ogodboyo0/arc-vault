// Circle Programmable Wallets Onboarding Script
const { Circle, CircleEnvironments } = require('@circle-fin/user-controlled-wallets');

class CircleWalletOnboarding {
    constructor(apiKey, entitySecret) {
        this.client = new Circle({
            apiKey: apiKey,
            environment: CircleEnvironments.TESTNET
        });
        this.entitySecret = entitySecret;
    }

    async createBorrowerWallet(userId) {
        try {
            const response = await this.client.createUser({
                userId: userId
            });
            return response.data;
        } catch (error) {
            console.error("Error creating user wallet:", error);
            throw error;
        }
    }

    async createUserToken(userId) {
        try {
            const response = await this.client.createUserToken({
                userId: userId
            });
            return response.data.userToken;
        } catch (error) {
            console.error("Error generating user token:", error);
            throw error;
        }
    }

    async initializeUserChallenge(userToken, accountType = 'SCA') {
        try {
            const response = await this.client.createUserPinChallenge({
                userToken: userToken,
                accountType: accountType,
                blockchains: ['ARC-TESTNET']
            });
            return response.data.challengeId;
        } catch (error) {
            console.error("Error creating pin challenge:", error);
            throw error;
        }
    }
}

module.exports = CircleWalletOnboarding;
