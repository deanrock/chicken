//
//  ServerManager.m
//  Chicken of the VNC
//
//  Created by Jared McIntyre on Sat Jan 24 2004.
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//

#import "ServerDataManager.h"
#import "ServerFromPrefs.h"
#import <AppKit/AppKit.h>

#define RFB_PREFS_LOCATION  @"Library/Preferences/cotvnc.prefs"
#define RFB_HOST_INFO		@"HostPreferences"
#define RFB_SERVER_LIST     @"ServerList"
#define RFB_SAVED_SERVERS   @"SavedServers"

@implementation ServerDataManager

static ServerDataManager* instance = nil;

+ (void)initialize
{
	[ServerDataManager setVersion:1];
}

- (id)init
{
	if( self = [super init] )
	{
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(applicationWillTerminate:)
													 name:@"NSApplicationWillTerminateNotification" object:NSApp];
		
		servers = [[NSMutableDictionary alloc] init];
		groups  = [[NSMutableDictionary alloc] init];
		
		[groups setObject:[NSMutableArray array] forKey:@"All"];
		[groups setObject:[NSMutableArray array] forKey:@"Rendezvous"];
		[groups setObject:[NSMutableArray array] forKey:@"Standard"];
	}
	
	return self;
}

- (id)initWithOriginalPrefs
{
	if( self = [self init] )
	{
		NSEnumerator* hostEnumerator = [[[NSUserDefaults standardUserDefaults] objectForKey:RFB_HOST_INFO] keyEnumerator];
		NSEnumerator* objEnumerator = [[[NSUserDefaults standardUserDefaults] objectForKey:RFB_HOST_INFO] objectEnumerator];
		NSString* host;
		NSDictionary* obj;
		while( host = [hostEnumerator nextObject] )
		{
			obj = [objEnumerator nextObject];
			id<IServerData> server = [ServerFromPrefs createWithHost:host preferenceDictionary:obj];
			if( nil != server )
			{
				[server setDelegate:self];
				[servers setObject:server forKey:[server name]];
			}
		}
	}
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[self save];
		
    [servers release];
    [super dealloc];
}

- (void)save
{
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject: instance];
	[[NSUserDefaults standardUserDefaults] setObject: data forKey: RFB_SAVED_SERVERS];
}

+ (ServerDataManager*) sharedInstance
{
	if( nil == instance )
	{
		NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:RFB_SAVED_SERVERS];
		instance = [NSKeyedUnarchiver unarchiveObjectWithData:data];
		
		if( nil == instance )
		{
			NSString *storePath = [NSHomeDirectory() stringByAppendingPathComponent:RFB_PREFS_LOCATION];
			
			instance = [NSKeyedUnarchiver unarchiveObjectWithFile:storePath];
			if( nil == instance )
			{
				// Didn't find any preferences under the new serialization system,
				// load based on the old system
				instance = [[ServerDataManager alloc] initWithOriginalPrefs];
				
				[instance save];
			}
			else
			{
				[instance retain];
			}
		}
		else
		{
			[instance retain];
		}
	}
	
	return instance;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    assert( [coder allowsKeyedCoding] );

	[coder encodeObject:servers forKey:RFB_SERVER_LIST];
    
	return;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [self init];
		
	if( nil != self )
	{
		assert( [coder allowsKeyedCoding] );
		
		servers = [[coder decodeObjectForKey:RFB_SERVER_LIST] retain];
		
		id<IServerData> server;
		NSEnumerator* objEnumerator = [servers objectEnumerator];
		while( server = [objEnumerator nextObject] )
		{
			[server setDelegate:self];
		}
	}
	
    return self;
}


- (void)applicationWillTerminate:(NSNotification *)notification
{
	if( nil != instance )
	{
		[instance release];
	}
}

- (NSEnumerator*) getServerEnumerator
{
	return [servers objectEnumerator];
}

- (NSEnumerator*) getGroupNameEnumerator
{
	return [groups keyEnumerator];
}

- (id<IServerData>)getServerWithName:(NSString*)name
{
	return [servers objectForKey:name];
}

- (id<IServerData>)getServerAtIndex:(int)index
{
	if( 0 > index )
	{
		return nil;
	}
	
	return [[servers allValues] objectAtIndex:index];
}

- (void)removeServer:(id<IServerData>)server
{
	[servers removeObjectForKey:[server name]];
	[servers removeObjectForKey:[server name]];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerListChangeMsg
														object:self];
}

- (void)makeNameUnique:(NSMutableString*)name
{
	if(nil != [servers objectForKey:name])
	{
		int numHelper = 0;
		NSString* newName;
		do
		{
			numHelper++;
			newName = [NSString stringWithFormat:@"%@_%d", name, numHelper];
		}while( nil != [servers objectForKey:newName] );
		
		[name setString: newName];
	}
}

- (id<IServerData>)createServerByName:(NSString*)name
{
	NSMutableString *nameHelper = [NSMutableString stringWithString:name];
	
	[self makeNameUnique:nameHelper];
	
	ServerFromPrefs* newServer = [ServerFromPrefs createWithName:nameHelper];
	[servers setObject:newServer forKey:[newServer name]];
	
	assert( nil != [servers objectForKey:nameHelper] );
	assert( newServer == [servers objectForKey:nameHelper] );
	
	[newServer setDelegate:self];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerListChangeMsg
														object:self];
	
	return newServer;
}

- (void)validateNameChange:(NSMutableString *)name forServer:(id<IServerData>)server;
{
	if( nil != [servers objectForKey:[server name]] )
	{
		assert( server == [servers objectForKey:[server name]] );
		
		[servers removeObjectForKey:[server name]];

		[self makeNameUnique:name];

		[servers setObject:server forKey:name];
	}
}
@end
