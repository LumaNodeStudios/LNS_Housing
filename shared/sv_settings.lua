return {
    FurnitureImageStorage = {
        -- Options:
        -- 'local', (Not Recommended)
        -- 'qbox', (Qbox CDN - Recommended)
        -- 'fivemanage', (Recommended)
        -- 'r2', (Cloudflare - Recommended)
        Type = 'qbox',

        -- Qbox CDN Configuration (https://docs.qbox.re/dashboard/cdn)
        Qbox = {
            ApiKey = '20260719_0b0hNP0Hhe4e4hHbVY30Fjo', -- API key generated from your Qbox CDN dashboard
            PublicUrl = 'https://r2.qbox.re/lumanodestudios/housing/', -- Your Qbox CDN public URL space/folder
        },
        
        -- Fivemanage Configuration
        Fivemanage = {
            Url = 'https://api.fivemanage.com/api/v3/file',
            Token = '',
            PublicUrl = 'https://r2.fivemanage.com/', -- Your Fivemanage public URL space/folder
            Folder = '' -- Optional: uploads go into this folder on Fivemanage (uses the 'path' API field)
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