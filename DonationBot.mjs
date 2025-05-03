import { Client, Events, GatewayIntentBits } from "discord.js"
import express from "express"


const minPinAmount   = 5_000
const reactionEmojis = ["🙏", "💪"]
const robuxEmoji     = "<:emoji:1364748707374956595>"

const app = express()
app.use(express.json())

const client = new Client({
    intents: [
        GatewayIntentBits.Guilds,
        GatewayIntentBits.GuildMessages,
    ]
})



function getRandomReactionEmoji() {
    return reactionEmojis[Math.floor(Math.random() * reactionEmojis.length)]
}


app.post("/donation", async (request, response) => {
    const authorizationKey = process.env.KEY
    if (request.headers["x-authorization-key"] != authorizationKey) {
        return response.status(403).json({ error: "Insufficient permissions." })
    }

    const {username, amount} = request.body
    if (!username || !amount) {
        return response.status(400).json({ error: "Missing username and/or amount."})
    }

    try {
		const channelId = process.env.CHANNEL_ID;
		const channel   = await client.channels.fetch(channelId);
		if (!channel || !channel.isTextBased()) {
			return response.status(500).json({ error: "Channel not found or not text-based." })
        }

		const message = await channel.send(`${username} has donated ${robuxEmoji} **${amount}**`)
        const emoji   = getRandomReactionEmoji()

        await message.react(emoji)

        if (amount >= minPinAmount) {
            await message.pin()
        }
		
        response.status(200).json({ message: "Message sent successfully." })
	}
    catch (error) {
		console.error(`Failed to send message: ${error}.`)

		response.status(500).json({ error: "Failed to send message." })
	}
})

client.once(Events.ClientReady, readyClient => {
    const port = process.env.PORT
    const name = readyClient.user.tag

	app.listen(port, () => {
        console.log(`\n${name} ready and listening on port ${port}.`)
    })
})



client.login(process.env.TOKEN)
