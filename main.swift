import Foundation

// MARK: - 1. Data Models
struct GameData: Codable {
    let rooms: [Room]
    let startingRoomId: String
}

struct Room: Codable {
    let id: String
    var description: String // Mutable so we can change it (e.g., after killing goblin)
    var items: [String]
    let exits: [String: String]
    
    // State Flags
    var locked: Bool
    let keyId: String?
    let isDark: Bool
    var enemy: String? // Optional: "goblin", "orc", or null
}

// MARK: - 2. Game Manager
class GameManager {
    var rooms: [String: Room] = [:]
    var currentRoomId: String = ""
    var inventory: [String] = []
    var isPlaying = true
    
    // Global State for the Torch
    var isTorchLit = false
    
    func loadGame() {
        let fileManager = FileManager.default
        let currentPath = fileManager.currentDirectoryPath
        let filePath = currentPath + "/game.json"
        
        guard fileManager.fileExists(atPath: filePath) else {
            print("Error: game.json not found.")
            exit(1)
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            let decoder = JSONDecoder()
            let gameData = try decoder.decode(GameData.self, from: data)
            
            for room in gameData.rooms {
                self.rooms[room.id] = room
            }
            
            self.currentRoomId = gameData.startingRoomId
            print("--- Assets Loaded ---")
        } catch {
            print("Error parsing JSON: \(error)")
            exit(1)
        }
    }
    
    // MARK: - Game Loop Actions
    
    func printStatus() {
        guard let room = rooms[currentRoomId] else { return }
        
        print("\n------------------------------------------------")
        // Logic: If the room is dark and torch isn't lit, don't show description
        if room.isDark && !isTorchLit {
            print("It is pitch black! You can't see anything.")
        } else {
            print(room.description)
            if let enemy = room.enemy {
                print("DANGER: A \(enemy) is watching you!")
            }
            if !room.items.isEmpty {
                print("You see: \(room.items.joined(separator: ", "))")
            }
        }
        
        print("------------------------------------------------")
        print("Exits: \(room.exits.keys.joined(separator: ", "))")
        print("Inventory: \(inventory.joined(separator: ", "))")
        print("Commands: move [dir], take [item], use [item], quit")
        print("> ", terminator: "")
    }
    
    func processCommand(_ input: String) {
        let parts = input.lowercased().split(separator: " ")
        guard let verb = parts.first else { return }
        let noun = parts.dropFirst().joined(separator: " ")
        
        switch verb {
        case "move", "go":
            move(direction: noun)
        case "take", "grab":
            takeItem(named: noun)
        case "use":
            useItem(named: noun)
        case "quit", "exit":
            isPlaying = false
        default:
            print("I don't understand.")
        }
    }
    
    func move(direction: String) {
        guard let currentRoom = rooms[currentRoomId] else { return }
        
        // 1. Validate direction
        guard let nextRoomId = currentRoom.exits[direction] else {
            print("You can't go that way.")
            return
        }
        
        guard let nextRoom = rooms[nextRoomId] else { return }
        
        // 2. Check Logic: Locked Door?
        // Note: We check the lock on the CURRENT room (leaving the cell)
        if currentRoom.locked && direction == "north" { 
            print("The door is locked. You need to use a key first.")
            return
        }
        
        // 3. Check Logic: Enemy?
        if let enemy = currentRoom.enemy, direction == "north" {
            print(" The \(enemy) blocks your path! You cannot pass.")
            return
        }
        
        // 4. Check Logic: Darkness?
        // If next room is dark, and torch is NOT lit
        if nextRoom.isDark && !isTorchLit {
            print("It is too dark to go in there! You need to use a light source.")
            return
        }
        
        // Success!
        self.currentRoomId = nextRoomId
        
        if nextRoomId == "freedom" {
            print("\n*** YOU HAVE ESCAPED! ***")
            isPlaying = false
        }
    }
    
    func takeItem(named itemName: String) {
        guard var currentRoom = rooms[currentRoomId] else { return }
        
        // Prevent taking items if it's dark
        if currentRoom.isDark && !isTorchLit {
            print("It's too dark to find anything!")
            return
        }
        
        if let index = currentRoom.items.firstIndex(of: itemName) {
            currentRoom.items.remove(at: index)
            rooms[currentRoomId] = currentRoom
            inventory.append(itemName)
            print("Picked up \(itemName).")
        } else {
            print("No \(itemName) here.")
        }
    }
    
    // MARK: - New Feature: Use Item
    func useItem(named itemName: String) {
        
        // 1. Check if user has item
        guard inventory.contains(itemName) else {
            print("You don't have a \(itemName).")
            return
        }
        
        guard var currentRoom = rooms[currentRoomId] else { return }
        
        // 2. Handle specific item logic
        switch itemName {
            
        case "rusty_key":
            if currentRoom.locked && currentRoom.keyId == "rusty_key" {
                print("You insert the rusty key into the lock... CLICK! The door opens.")
                currentRoom.locked = false
                currentRoom.description = "You are in a cell. The door north is unlocked." // Update flavor text
                rooms[currentRoomId] = currentRoom // Save changes
            } else {
                print("You can't use that here.")
            }
            
        case "torch":
            if isTorchLit {
                print("The torch is already lit.")
            } else {
                print("You strike a flint. The torch flares to life! You can see now.")
                isTorchLit = true
            }
            
        case "sword":
            if let enemy = currentRoom.enemy {
                print("You swing the sword at the \(enemy)...")
                print("It's a direct hit! The \(enemy) falls to the ground, defeated.")
                
                currentRoom.enemy = nil // Remove enemy
                currentRoom.description = "You are at the main gate. A dead goblin lies on the floor."
                rooms[currentRoomId] = currentRoom // Save changes
            } else {
                print("You swing your sword at the air. Whoosh!")
            }
            
        default:
            print("You can't use the \(itemName).")
        }
    }
}

// MARK: - 3. Run Loop
let game = GameManager()
game.loadGame()

print("Welcome to the CLI Adventure.")
while game.isPlaying {
    game.printStatus()
    if let input = readLine() {
        game.processCommand(input)
    }
}
