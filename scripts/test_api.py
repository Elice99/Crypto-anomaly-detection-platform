'''
Test script for CoinGecko APIs
Purpose: Verify API connection and fetch first crypto data
'''

from pycoingecko import CoinGeckoAPI
import pandas as pd
from datetime import datetime

# Initialize CoinGecko API client
cg = CoinGeckoAPI()

def test_simple_price():
    '''Test 1: Fetch current price for Bitcoin'''
    print('=' * 50)
    print('TEST 1: Fetching Bitcoin current price')
    print('=' * 50)
    
    # Get Bitcoin price in USD
    btc = cg.get_price(ids='bitcoin', vs_currencies='usd')
    
    print(f'Bitcoin price: ${btc['bitcoin']['usd']:,.2f}')
    print()
    

def test_multiple_coin():
    '''Test 2: Fetch prices for multiple coins'''
    print('=' * 50)
    print('TEST 2: Fetching Top 10 coins')
    print('=' * 50)
    
    # Get top 10 coins by market cap
    coins = cg.get_coins_markets(
        vs_currency='usd',
        per_page = 10,
        page = 1,
        order = 'market_cap_desc'
    )
    
    # Convert to DataFrame for nice display
    df = pd.DataFrame(coins)
    
    # Select relevant columns
    display_df = df[['name', 'symbol', 'current_price', 'market_cap', 'total_volume']]
    
    print(display_df.to_string(index=False))
    print(f'\n Successfully fetched {len(coins)} coins')
    print()
    
    
def test_historical_data():
    '''Test 3: Fetch Historical data for Bitcoin'''
    print('=' * 50)
    print('TEST 3: Fetching Bitcoin 7-day history')
    print('=' * 50)
    
    # Get 7 days of Bitcoin price history
    history = cg.get_coin_market_chart_by_id(
        id ='bitcoin',
        vs_currency = 'usd',
        days = 7
    )
    
    # Extract price data
    prices = history['prices']
    
    # Convert to DataFrame
    df = pd.DataFrame(prices, columns = ['timestamp', 'price'])
    df['data'] = pd.to_datetime(df['timestamp'], unit='ms')
    
    print(f'Fetched {len(df)} data points')
    print('\nFirst 5 records:')
    print(df[['data', 'price']].head().to_string(index=False))
    print('\nLast 5 records:')
    print(df[['data', 'price']].tail().to_string(index=False))
    print()
    
    
def test_api_status():
    '''Test 4: Check API health'''
    print('=' * 50)
    print('TEST 4: Checking CoinGecko API status')
    print('=' * 50)
        
    try:
        ping = cg.ping()
        print(f'API Status: {ping}')
        print('CoinGecko API is working perfectly!')
    except Exception as e:
        print(f'API Error: {e}')
    print()
    
    
if __name__ == '__main__':
    print('\n CRYPTO ANOMALY DETECTION PROJECT')
    print(f'Test stated at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}')
    print('\n')
    
    try:
        # Run all tests
        test_simple_price()
        test_multiple_coin()
        test_historical_data()
        test_api_status()
        
        print('=' * 50)
        print('ALL TEST PASSED!')
        print('=' * 50)
        
    except Exception as e:
        print(f'\nError occurred: {e}')
        print('Tip: Check your internet connection and try again')
            
        