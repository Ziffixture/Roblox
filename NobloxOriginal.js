// Environment Variables
require("dotenv").config();

// Dependencies
const express = require("express"),
  roblox = require("noblox.js");

// Initialize Express
const app = express();

// Initialize Middleware
app
  .use(express.json());

// Routes
app
  .post("/setrank/", async (req, res) => {

     // Authenticate Request
     const authorizationToken = req.headers["x-authorization-token"];
     if(!authorizationToken) return res.status(400);
     if(authorizationToken !== process.env.API_AUTHORIZATION_TOKEN) return res.status(401);

     // Parse Request Body
     const {
        user,
        rank
     } = req.body;

     // Check Body
     if(!user || !rank) return res.status(400);

     try {

        await (
          roblox
             .setRank(
                parseInt(process.env.ROBLOX_GROUP_ID),
                parseInt(user),
                parseInt(rank)
             )
        );

     } catch (e) {
  
        console.error(e);

        return res.status(500);

     }

     return res.status(200);

  });

// Initialize Application
const initialize = async () => {

   try {

     // Set Roblox Cookie
     await (
        roblox
          .setCookie(process.env.ROBLOX_COOKIE)
     );

     // Fetch Roblox User Details
     const currentUser = await (roblox.getCurrentUser());
     console.log(`Logged in as ${currentUser.UserName}`);

     // Start Express Server
     app.listen(process.env.API_PORT, () =>
        console.log(`Your application is listening on port ${process.env.API_PORT}`)
     );

   } catch (e) {

     console.error(e);

   }

};

// Run Initialization Function
initialize();
