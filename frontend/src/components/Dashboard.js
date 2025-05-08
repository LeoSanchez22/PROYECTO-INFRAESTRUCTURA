import React, { useEffect, useState } from 'react';
import { API, graphqlOperation } from 'aws-amplify';
import { useNavigate } from 'react-router-dom';

const Dashboard = ({ user }) => {
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);
  const [processInput, setProcessInput] = useState('');
  const navigate = useNavigate();

  useEffect(() => {
    if (!user) {
      navigate('/');
      return;
    }
    
    fetchData();
  }, [user, navigate]);

  async function fetchData() {
    setLoading(true);
    try {
      const operation = `query GetData {
        getData
      }`;
      
      const response = await API.graphql(graphqlOperation(operation));
      setData(response.data.getData);
      setError(null);
    } catch (error) {
      console.error('Error fetching data:', error);
      setError('Failed to fetch data. Please try again later.');
      setData(null);
    } finally {
      setLoading(false);
    }
  }

  async function processData() {
    if (!processInput.trim()) {
      setError('Please enter some data to process');
      return;
    }

    setLoading(true);
    try {
      const operation = `mutation ProcessData($input: String!) {
        processData(input: $input)
      }`;
      
      const variables = {
        input: processInput
      };
      
      const response = await API.graphql(graphqlOperation(operation, variables));
      setData(response.data.processData);
      setError(null);
      setProcessInput('');
    } catch (error) {
      console.error('Error processing data:', error);
      setError('Failed to process data. Please try again later.');
    } finally {
      setLoading(false);
    }
  }

  if (!user) {
    return null;
  }

  return (
    <div>
      <h2>Dashboard</h2>
      
      <div className="graphql-data">
        <h3>GraphQL Operations</h3>
        
        <div>
          <h4>Process

