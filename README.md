# Enhanced Trucker Job

An enhanced trucker job system for FiveM with a modern NUI interface and F6 key functionality.

## Features

- **F6 Key Interface**: Press F6 to open/close the trucker job interface
- **Modern NUI**: Beautiful, responsive interface with real-time status updates
- **Vehicle Management**: Rent and return vehicles through the NUI
- **Paycheck System**: Collect paychecks directly from the interface
- **Smart Menu States**: Buttons are enabled/disabled based on current job status
- **Delivery System**: Complete delivery missions with proper tracking
- **NPC Integration**: Interactive NPCs for job management

## Installation

1. Place the resource in your server's resources folder
2. Add `ensure qbx_truckerjob` to your server.cfg
3. Restart your server

## Dependencies

- qbx_core
- ox_lib
- ox_target

## Usage

### For Players

1. **Starting the Job**:
   - Go to the trucker depot location
   - Press F6 to open the interface
   - Click "Rent Vehicle" to start working

2. **During the Job**:
   - Press F6 anytime to check your status
   - Complete deliveries as assigned
   - Return to depot when finished

3. **Ending the Job**:
   - Press F6 and click "Return Vehicle"
   - Collect your paycheck

### Controls

- **F6**: Open/close NUI interface
- **Escape**: Close NUI interface
- **Click outside**: Close NUI interface

### NUI Features

- **Real-time Status**: Shows current job status, deliveries completed, and vehicle info
- **Smart Buttons**: 
  - "Rent Vehicle" - Always available when no active job
  - "Return Vehicle" - Only available when job is active
  - "Collect Paycheck" - Always available

## Configuration

### Client Config (`config/client.lua`)
```lua
return {
    useTarget = GetConvar('UseTarget', 'false') == 'true',
    debug = false
}
```

### Server Config (`config/server.lua`)
```lua
return {
    job = {
        maxLocations   = 10,        -- max delivery stops per run
        spawnBreakTime = 300000,   -- cooldown (5 mins) between jobs
        bailPrice      = 250,      -- rental fee
        paymentTax     = 15        -- tax percentage
    },
    -- ... more options
}
```

### Shared Config (`config/shared.lua`)
- Delivery locations (stores and houses)
- Vehicle configurations
- Payment settings
- Animation settings

## Customization

### Adding New Delivery Locations

Edit `config/shared.lua` and add new locations to the `deliveries.stores` or `deliveries.houses` tables:

```lua
deliveries = {
    stores = {
        [14] = { 
            label = 'New Store', 
            coords = vec3(x, y, z), 
            size = vec3(40, 40, 5), 
            icon = 'fa-solid fa-store', 
            debug = false 
        }
    }
}
```

### Adding New Vehicles

Add new vehicles to the `vehicles` table in `config/shared.lua`:

```lua
vehicles = {
    [GetHashKey('mule')] = 'Mule Truck',
    [GetHashKey('new_vehicle')] = 'New Vehicle Name'
}
```

## Troubleshooting

### Common Issues

1. **NUI not opening**: Check if ox_lib is properly installed
2. **Vehicles not spawning**: Verify vehicle models exist in your server
3. **NPCs not appearing**: Check if ox_target is installed and configured

### Debug Mode

Enable debug mode in `config/client.lua`:
```lua
debug = true
```

This will print detailed information to the console for troubleshooting.

## Support

For support, please check:
1. Your server console for error messages
2. The debug output (if enabled)
3. That all dependencies are properly installed

## License

This resource is provided as-is for educational and server use.