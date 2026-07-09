return {
    FurnitureImageStorage = {
        -- Options:
        -- 'local', (Not Recommended)
        -- 'fivemanage', (Recommended)
        -- 'r2', (Cloudflare - Recommended)
        Type = 'fivemanage',
        
        -- Fivemanage Configuration
        Fivemanage = {
            Url = 'https://api.fivemanage.com/api/v3/file',
            Token = 'xOSaS3kRrUNyEvNBnWg2FWdxX8uKg2Zp'
        },
        
        -- Cloudflare R2 Configuration
        R2 = {
            AccountId = '8424ec7d0de6f49140701ff4a633cdb2',
            AccessKeyId = 'a3ec2ab4e7d9f35cbc9116c416272b4f',
            SecretAccessKey = '0275dde296d3d35105347bc034e86a2298039d25bc0c06c465c6f7fe42ebc9e7',
            Bucket = 'fivem-assets',
            Folder = 'Props/Furniture', -- Optional folder prefix inside bucket
            PublicUrl = 'https://pub-646819b22eaa4dfd89864003fd6c680d.r2.dev' -- The public domain to access files
        }
    }
}