import SpriteKit



// MARK: Operators Overloading Functions

func + (left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x + right.x, y: left.y + right.y)
}

func - (left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x - right.x, y: left.y - right.y)
}

func * (point: CGPoint, scalar: CGFloat) -> CGPoint {
    return CGPoint(x: point.x * scalar, y: point.y * scalar)
}

func / (point: CGPoint, scalar: CGFloat) -> CGPoint {
    return CGPoint(x: point.x / scalar, y: point.y / scalar)
}


#if !(arch(x86_64) || arch(arm64))
    func sqrt(a: CGFloat) -> CGFloat {
        return CGFloat(sqrtf(Float(a)))
    }
#endif

extension CGPoint {
    func length() -> CGFloat { // gives float
        return sqrt(x*x + y*y)
    }
    
    func normalized() -> CGPoint { // gives a point
        return self / length()
    }
}




struct PhysicsCategories{
    static let None        : UInt32 = 0
    static let All         : UInt32 = UInt32.max
    static let Monster     : UInt32 = 0b1
    static let Projectile  : UInt32 = 0b10
}




class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // 1
    let player = SKSpriteNode(imageNamed: "player")
    var scoreLbl = SKLabelNode()
    
    var monsterHits = 0
    
    
    // MARK: SKScene Class Methods
    
    override func didMove(to view: SKView) {
        // 2
        backgroundColor = SKColor.gray
        // 3
        player.position = CGPoint(x: size.width * 0.1, y: size.height * 0.5)
        player.zPosition = 2
        // 4
        addChild(player)
        
        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
        physicsWorld.contactDelegate = self
        
        run(SKAction.repeatForever(
            SKAction.sequence(
                [SKAction.run(addMonster), SKAction.wait(forDuration: 1.0)]
            )
        ))
        
        
        if #available(iOS 9.0, *) {
            let audio = SKAudioNode(fileNamed: "background-music-aac.caf")
            audio.autoplayLooped = true
            print(audio)
            addChild(audio)
        } else {
            // Fallback on earlier versions
        }
        
        scoreLbl.position = CGPoint(x: size.width * 0.05, y: size.height * 0.5)
        scoreLbl.fontSize = 50
        scoreLbl.zPosition = 40
        scoreLbl.fontColor = SKColor.red
        scoreLbl.text = "\(monsterHits)"
        addChild(scoreLbl)
        
        addBackrnd()
        
    }
    
    
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
       run(SKAction.playSoundFileNamed("pew-pew-lei.caf", waitForCompletion: false))
        
        
        // 1 - Choose one of the touches to work with
        guard let touch = touches.first else {
            return
        }
        let touchLocation = touch.location(in: self)
        
        // 2 - Set up initial location of projectile
        let projectile = SKSpriteNode(imageNamed: "projectile")
        projectile.position = player.position
        projectile.physicsBody = SKPhysicsBody(circleOfRadius: projectile.size.width/2)
        projectile.physicsBody?.categoryBitMask = PhysicsCategories.Projectile
        projectile.physicsBody?.contactTestBitMask = PhysicsCategories.Monster
        projectile.physicsBody?.collisionBitMask = PhysicsCategories.None
        projectile.physicsBody?.isDynamic = true
        projectile.physicsBody?.usesPreciseCollisionDetection = true
        projectile.zPosition = 3
        
        
        
        // 3 - Determine offset of location to projectile
        let offset = touchLocation - projectile.position
        
        // 4 - Bail out if you are shooting down or backwards
        if (offset.x < 0) { return }
        
        // 5 - OK to add now - you've double checked position
        addChild(projectile)
        
        // 6 - Get the direction of where to shoot
        let direction = offset.normalized()
        
        // 7 - Make it shoot far enough to be guaranteed off screen
        let shootAmount = direction * 1000
        
        // 8 - Add the shoot amount to the current position
        let realDest = shootAmount + projectile.position
        
        // 9 - Create the actions
        let actionMove = SKAction.move(to: realDest, duration: 2.0)
        let actionMoveDone = SKAction.removeFromParent()
        projectile.run(SKAction.sequence([actionMove, actionMoveDone]))
        
    }
    
    
    
    
    override func update(_ currentTime: TimeInterval) {
        /* Called before each frame is rendered */
        
                enumerateChildNodes(withName: "Backrnd", using: ({
                    (node, error) in
                    
                    let backrnd = node as! SKSpriteNode
                    
                    backrnd.position = CGPoint(x: backrnd.position.x - 2, y: backrnd.position.y)
                    
                    if backrnd.position.x <= -backrnd.size.width{
                        backrnd.position = CGPoint(x: backrnd.position.x + backrnd.size.width * 2, y: backrnd.position.y)
                    }
                    
                }))
    }
    
    
    
    
    // MARK: Helper Methods
    
    func random() -> CGFloat{
        return CGFloat(Float(arc4random()) / 0xFFFFFFFF)
    }
    
    
    
    func random(min:CGFloat, max: CGFloat) -> CGFloat  {
        
        return random() * (max - min) + min
    }
    
    
    func addMonster(){
        
        let monster = SKSpriteNode(imageNamed: "monster")
        monster.physicsBody = SKPhysicsBody(rectangleOf: monster.size)
        monster.physicsBody?.isDynamic = true
        monster.physicsBody?.categoryBitMask = PhysicsCategories.Monster
        monster.physicsBody?.contactTestBitMask = PhysicsCategories.Projectile
        monster.physicsBody?.collisionBitMask = PhysicsCategories.None
        
        // Determine where to spawn the monster along the Y axis
        let actualY = random(min: monster.size.height/2, max: size.height - monster.size.height/2)
        
        monster.position = CGPoint(x: size.width + monster.size.width / 2, y: actualY)
        monster.zPosition = 3
        addChild(monster)
        
        let actualDuration = random(min: CGFloat(2.0), max: CGFloat(4.0))
        
        let actionMove = SKAction.move(to: CGPoint(x: -monster.size.width/2, y: actualY), duration: TimeInterval(actualDuration))
        
        let actionMoveDone = SKAction.removeFromParent()
        
        let loseAction = SKAction.run { 
            let gameOverScene = GameOverScene(size: self.size, won: false, score: self.monsterHits)
            let revealTransition = SKTransition.flipHorizontal(withDuration: 0.5)
            self.view?.presentScene(gameOverScene, transition: revealTransition)
        }
        
        monster.run(SKAction.sequence([actionMove, loseAction, actionMoveDone]))
    }
    
    
    
    func addBackrnd(){
        for i in 0..<2 {
            let backrnd = SKSpriteNode(imageNamed: "backrnd")
            backrnd.anchorPoint = CGPoint.zero
            backrnd.position = CGPoint(x: CGFloat(i) * self.frame.width, y: 0)
            backrnd.name = "Backrnd"
            backrnd.size = (self.view?.bounds.size)!
            backrnd.zPosition = 1
            self.addChild(backrnd)
        }
    }

    
    
    
    func projectileDidCollideWithMonster(_ projectile:SKSpriteNode, monster: SKSpriteNode){
        print("Hit")
        monsterHits += 1
        scoreLbl.text = "\(monsterHits)"
        
        if monsterHits >= 30{
                let gameOver = GameOverScene(size: self.size, won: true, score: self.monsterHits)
                let transition = SKTransition.flipHorizontal(withDuration: 0.5)
                self.view?.presentScene(gameOver, transition: transition)
        }
        
        projectile.removeFromParent()
        monster.removeFromParent()
        
    }
    
    
    
        
        // MARK: SKPhysicsContactDelegate
        
        func didBegin(_ contact: SKPhysicsContact){
            
            var bodyA: SKPhysicsBody
            var bodyB: SKPhysicsBody
            
            if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
                bodyA = contact.bodyA
                bodyB = contact.bodyB
            }
            else{
                bodyA = contact.bodyB
                bodyB = contact.bodyA
            }
            
            
            if (bodyA.categoryBitMask & PhysicsCategories.Monster != 0) && (bodyB.categoryBitMask & PhysicsCategories.Projectile != 0) {
                
                projectileDidCollideWithMonster(bodyA.node as! SKSpriteNode, monster: bodyB.node as! SKSpriteNode)
                
            }
            
            
            
        }
   
    
    
    
    
    
    
    
    
    
    
    
    
}
