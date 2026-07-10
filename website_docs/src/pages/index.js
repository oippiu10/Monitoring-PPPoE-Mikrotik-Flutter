import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import HomepageFeatures from '@site/src/components/HomepageFeatures';

import Heading from '@theme/Heading';
import styles from './index.module.css';

function HomepageHeader() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <header className={clsx('hero hero--primary', styles.heroBanner)}>
      <div className="container">
        <div className="row" style={{alignItems: 'center'}}>
          <div className="col col--6" style={{textAlign: 'left'}}>
            <Heading as="h1" className="hero__title">
              {siteConfig.title}
            </Heading>
            <p className="hero__subtitle" style={{marginBottom: '30px'}}>{siteConfig.tagline}</p>
            <div className={styles.buttons}>
              <Link
                className="button button--secondary button--lg"
                to="/docs/intro">
                Mulai Baca Dokumentasi 📖
              </Link>
            </div>
          </div>
          <div className="col col--6">
            <img 
              src={require('@site/static/img/screenshots/04_Dashboard_Home.jpg').default} 
              alt="Dashboard Preview" 
              style={{maxHeight: '500px', borderRadius: '15px', boxShadow: '0 20px 40px rgba(0,0,0,0.4)', transform: 'rotate(2deg)'}}
            />
          </div>
        </div>
      </div>
    </header>
  );
}

export default function Home() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout
      title={`Hello from ${siteConfig.title}`}
      description="Description will go into a meta tag in <head />">
      <HomepageHeader />
      <main>
        <HomepageFeatures />
      </main>
    </Layout>
  );
}
