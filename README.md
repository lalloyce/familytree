# Family Tree Web App

## Overview

This Family Tree Web App allows users to register, log in, and manage their family tree. The app uses MongoDB for data storage, Express for the backend, and React for the frontend. The app is deployed on Vercel.

## Features

- User registration and login
- Add family members
- View family tree
- Secure access with JWT authentication

## Prerequisites

- Node.js
- MongoDB Atlas account
- Vercel account

## Installation

### Backend

1. Clone the repository:

    ```bash
    git clone https://github.com/lalloyce/familytree.git
    cd familytree/server
    ```

2. Install dependencies:

    ```bash
    npm install
    ```

3. Create a `.env` file in the `server` directory with the following content:

    ```env
    PORT=5000
    MONGODB_URI=your_mongodb_uri_here
    JWT_SECRET=your_jwt_secret_here
    ```

4. Start the server:

    ```bash
    npm run dev
    ```

### Frontend

1. Navigate to the `client` directory:

    ```bash
    cd ../client
    ```

2. Install dependencies:

    ```bash
    npm install
    ```

3. Start the React app:

    ```bash
    npm start
    ```

## Directory Structure

familytree/
├── client/ # React frontend
│ ├── public/
│ ├── src/
│ ├── package.json
│ ├── README.md
│ └── ...
├── server/ # Express backend
│ ├── controllers/
│ ├── middleware/
│ ├── models/
│ ├── routes/
│ ├── index.js
│ ├── .env
│ └── ...
├── README.md
└── ...

markdown
Copy code

## Usage

1. Register a new user.
2. Log in with the registered user credentials.
3. Add family members by providing details like name, gender, year of birth, parent ID, and spouse ID.
4. View the family tree.

## Deployment

### Backend

1. Create a new project on Vercel and select the `server` directory as the root directory.
2. Set the environment variables (`MONGODB_URI`, `JWT_SECRET`, `PORT`) in Vercel.
3. Deploy the project.

### Frontend

1. Create a new project on Vercel and select the `client` directory as the root directory.
2. Add a proxy in your `client/package.json` to forward API requests to your backend:

    ```json
    "proxy": "https://your-backend-url.vercel.app"
    ```

3. Deploy the project.

## Contributing

Feel free to open issues or submit pull requests if you have suggestions or improvements.

## License

This project is licensed under the MIT License.
