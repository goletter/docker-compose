import hudson.security.HudsonPrivateSecurityRealm
import jenkins.model.Jenkins

def username = System.getenv('JENKINS_ADMIN_ID') ?: 'admin'
def password = System.getenv('JENKINS_ADMIN_PASSWORD')
if (!password) {
    return
}

def instance = Jenkins.get()
def realm = instance.securityRealm
if (!(realm instanceof HudsonPrivateSecurityRealm)) {
    realm = new HudsonPrivateSecurityRealm(false)
    instance.setSecurityRealm(realm)
}

def user = hudson.model.User.getById(username, false)
if (user == null) {
    realm.createAccount(username, password)
} else {
    user.addProperty(HudsonPrivateSecurityRealm.Details.fromPlainPassword(password))
    user.save()
}

def passwordFile = new File(instance.rootDir, 'secrets/initialAdminPassword')
passwordFile.setText(password, 'US-ASCII')
instance.save()
println("Jenkins admin '${username}' password set from JENKINS_ADMIN_PASSWORD")
