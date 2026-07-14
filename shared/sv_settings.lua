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
            Token = 'xOSaS3kRrUNyEvNBnWg2FWdxX8uKg2Zp',
            PublicUrl = 'https://r2.fivemanage.com/ikenZGXRwE4faTVyko8MZ/Furniture', -- Your Fivemanage public URL space/folder
            Folder = 'Furniture' -- Optional: uploads go into this folder on Fivemanage (uses the 'path' API field)
        },
        
        -- Cloudflare R2 Configuration
        R2 = {
            AccountId = '',
            AccessKeyId = '',
            SecretAccessKey = '',
            Bucket = 'fivem-assets',
            Folder = 'Props/Furniture', -- Optional folder prefix inside bucket
            PublicUrl = 'https://pub-xxx.r2.dev' -- The public domain to access files
        }
    }
}