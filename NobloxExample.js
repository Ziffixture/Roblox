import express from "express"
import noblox from "noblox"



const app = express()
app.use(express.json())



app.post("/setrank/", async (request, response) => {
    const authorizationToken = request.headers["x-authorization-token"]
    
    if (!authorizationToken)
        return response.status(400)

    if (authorizationToken !== process.env.API_AUTHORIZATION_TOKEN)
        return response.status(401)
        
    const {user, rank} = request.body
    
    if (!(user && rank))
        return response.status(400)
        
    try {
        await noblox.setRank(
        
            Number(process.env.ROBLOX_GROUP_ID),
            Number(user),
            Number(rank)
            
        )
    }
    catch (error) {
        console.log(error)
        
        return response.status(500)
    }
    
    return response.status(200)
})



await roblox.setCookie(process.env.ROBLOX_COOKIE)

const currentUser = await roblox.getCurrentUser();
console.log(`Logged in as ${currentUser.UserName}`);

app.listen(process.env.API_PORT, () => 
    console.log(`Your application is listening on port ${process.env.API_PORT}`)
)
