//
//  GenericAccount.m
//  ASiST
//
//  Created by Oliver on 09.11.09.
//  Copyright 2009 Drobnik.com. All rights reserved.
//

#import "GenericAccount.h"
#import <Security/Security.h>



@interface GenericAccount ()

- (NSMutableDictionary *)makeUniqueSearchQuery;  // mutable, if primary keys are updated
- (void)writeToKeychain;


@property(nonatomic, retain) NSString *pk_account;
@property(nonatomic, retain) NSString *pk_service;

@end


@implementation GenericAccount
{
}

@synthesize account, description, comment, label, service, password, pk_account, pk_service;

//static const UInt8 kKeychainIdentifier[]    = "com.cocoanetics.AutoIngest.KeychainUI\0";

#pragma mark Init/dealloc	

- (id) initFromKeychainDictionary:(NSDictionary *)dict
{
	if (self = [super init])
	{
		account = [[dict objectForKey:(id)kSecAttrAccount] copy];
		description = [[dict objectForKey:(id)kSecAttrDescription] copy];
		comment = [[dict objectForKey:(id)kSecAttrComment] copy];
		label = [[dict objectForKey:(id)kSecAttrLabel] copy];
		service = [[dict objectForKey:(id)kSecAttrService] copy];
		
        NSData *passwordData = [dict objectForKey:(id)kSecValueData];
        if (passwordData)
        {
            password = [[NSString alloc] initWithData:passwordData encoding:NSUTF8StringEncoding];
        }
		
		keychainData = [dict mutableCopy];
		
		// remember primary key 
		self.pk_account = account;
		self.pk_service = service;
		
		//uniqueSearchQuery = [[self makeUniqueSearchQuery] retain];
		
		[keychainData setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass]; 
		
		
		dirty = NO;
	}
	
	return self;
}


- (id) initService:(NSString *)aService forUser:(NSString *)aUser
{
	if (self = [super init])
	{
		account = [aUser copy];
		service = [aService copy];
		
		// remember primary key 
		self.pk_account = account;
		self.pk_service = service;
		
		keychainData = [NSMutableDictionary dictionary];
		
		[keychainData setObject:account forKey:(id)kSecAttrAccount];
		[keychainData setObject:service forKey:(id)kSecAttrService];
		
		[keychainData setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
		
//		NSData *keychainType = [NSData dataWithBytes:kKeychainIdentifier length:strlen((const char *)kKeychainIdentifier)];
//		[keychainData setObject:keychainType forKey:(id)kSecAttrGeneric];
		
		[self writeToKeychain];
		
	}
	
	return self;
}


#pragma mark Keychain Access 
// search query to find only this account on the keychain
- (NSMutableDictionary *)makeUniqueSearchQuery
{
	NSMutableDictionary *genericPasswordQuery = [[NSMutableDictionary alloc] init];
	[genericPasswordQuery setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
//	NSData *keychainType = [NSData dataWithBytes:kKeychainIdentifier length:strlen((const char *)kKeychainIdentifier)];
//	[genericPasswordQuery setObject:keychainType forKey:(id)kSecAttrGeneric];
	
//	// Use the proper search constants, return only the attributes of the first match.
//	[genericPasswordQuery setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];
//	[genericPasswordQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnAttributes];
	
	// also limit to current pk
	[genericPasswordQuery setObject:pk_account forKey:(id)kSecAttrAccount];
	[genericPasswordQuery setObject:pk_service forKey:(id)kSecAttrService];
	
	return genericPasswordQuery;
}

- (void)writeToKeychain
{
    CFDictionaryRef attributes = NULL;
 	NSDictionary *uniqueSearchQuery = [self makeUniqueSearchQuery];
	
    if (SecItemCopyMatching((__bridge CFDictionaryRef)uniqueSearchQuery, (CFTypeRef *)&attributes) == noErr)
    {
        NSMutableDictionary *updateQuery = [NSMutableDictionary dictionary];
 		
		// we copy the class, service and account as search values
        [updateQuery setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
		[updateQuery setObject:pk_account forKey:(id)kSecAttrAccount];
		[updateQuery setObject:pk_service forKey:(id)kSecAttrService];
        
        NSMutableDictionary *updatedValues = [NSMutableDictionary dictionary];
        [updatedValues setObject:account forKey:(id)kSecAttrAccount];
        [updatedValues setObject:[password dataUsingEncoding:NSUTF8StringEncoding] forKey:(id)kSecValueData];
		
        // An implicit assumption is that you can only update a single item at a time.
        OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)(updateQuery), (__bridge CFDictionaryRef)(updatedValues));
        
        if (status)
        {
            NSLog(@"Couldn't update the Keychain Item.");
        }
		
		pk_account = account;
		pk_service = service;
		
		CFRelease(attributes);
    }
    else
    {
        // No previous item found, add the new one.
		
		/*
		 2009-09-08 09:30:51.197 MyAppSales[4461:207] keychain item: {
		 acct = one;
		 class = genp;
		 gena = <636f6d2e 64726f62 6e696b2e 61736973 742e4b65 79636861 696e5549>;
		 svce = last4;
		 }
		 
		 --> secitem is identical
		 
		 */
		
        if (SecItemAdd((__bridge CFDictionaryRef)(keychainData), NULL) != noErr)
        {
            NSLog(@"Couldn't add the Keychain Item.");

        }
    }
	
	dirty = NO;
}


- (void)removeFromKeychain
{
	OSStatus junk = noErr;
    if (!keychainData) 
    {
        keychainData = [[NSMutableDictionary alloc] init];
    }
    else if (keychainData)
    {
		/*
		 
		 secitem: {
		 acct = "oliver@drobnik.com";
		 agrp = "6P2Z3HB85N.com.drobnik.MyAppSales";
		 class = genp;
		 gena = <636f6d2e ... >;
		 svce = "iTunes Connect";
		 }
		 
		 
		 keychain: {
		 acct = "oliver@drobnik.com";
		 agrp = "6P2Z3HB85N.com.drobnik.MyAppSales";
		 gena = <636f6d2e ...>;
		 svce = "iTunes Connect";
		 
		 ---> class missing causes delete to fail
		 
		 */
		
		[keychainData setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];  // without class this fails
		
		junk = SecItemDelete((__bridge CFDictionaryRef)keychainData);
        
        if ( junk != noErr && junk != errSecItemNotFound)
        {
            NSLog(@"Problem deleting current dictionary.");
        }
    }
}


- (void)setObject:(id)inObject forKey:(id)key 
{
    if (inObject == nil) return;
    id currentObject = [keychainData objectForKey:key];
    if (![currentObject isEqual:inObject])
    {
        [keychainData setObject:inObject forKey:key];
        [self writeToKeychain];
    }
}

#pragma mark Setters

- (void) setAccount:(NSString *)newAccount
{
	if (account != newAccount) 
	{
		account = [newAccount copy];
		
		[self setObject:account forKey:(id)kSecAttrAccount];
		
		// update unique search query as well because this is part of primary key
		//[uniqueSearchQuery setObject:newAccount forKey:(id)kSecAttrAccount];
		
		dirty = YES;
	}
}

- (void) setPassword:(NSString *)newPassword
{
	if (password != newPassword) 
	{
		password = [newPassword copy];
		
		// password is NSData in keychain, need to convert
		
		[self setObject:[password dataUsingEncoding:NSUTF8StringEncoding] forKey:(id)kSecValueData];
		dirty = YES;
	}
}

- (void) setService:(NSString *)newService
{
	if (service != newService) 
	{
		service = [newService copy];
		
		[self setObject:service forKey:(id)kSecAttrService];
		
		// update unique search query as well because this is part of primary key
		//[uniqueSearchQuery setObject:newService forKey:(id)kSecAttrService];
		
		dirty = YES;
	}
}

- (void) setDescription:(NSString *)newDescription
{
	if (description != newDescription) 
	{
		description = [newDescription copy];
		
		[self setObject:description forKey:(id)kSecAttrDescription];
		dirty = YES;
	}
}

- (void) setLabel:(NSString *)newLabel
{
	if (label != newLabel) 
	{
		label = [newLabel copy];
		
		[self setObject:label forKey:(id)kSecAttrLabel];
		dirty = YES;
	}
}

- (void) setComment:(NSString *)newComment
{
	if (comment != newComment) 
	{
		comment = [newComment copy];
		
		[self setObject:comment forKey:(id)kSecAttrComment];
		dirty = YES;
	}
}

- (NSString *)password
{
    if (!password)
    {
        NSMutableDictionary *updateQuery = [NSMutableDictionary dictionary];
 		
		// we copy the class, service and account as search values
        [updateQuery setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
		[updateQuery setObject:pk_account forKey:(id)kSecAttrAccount];
		[updateQuery setObject:pk_service forKey:(id)kSecAttrService];
        [updateQuery setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];
        [updateQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnAttributes];
        [updateQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
        
        CFDictionaryRef attributes = NULL;
        
        if (SecItemCopyMatching((__bridge CFDictionaryRef)updateQuery, (CFTypeRef *)&attributes) == noErr)
        {
            password = [[NSString alloc] initWithData:[(__bridge NSDictionary *)attributes objectForKey:(id)kSecValueData] encoding:NSUTF8StringEncoding];
        }
        
        CFRelease(attributes);
    }
    
    return password;
}

@end
